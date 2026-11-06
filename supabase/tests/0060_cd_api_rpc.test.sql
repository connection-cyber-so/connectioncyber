-- 0060 teste da camada de API com dado 100% FICTICIO e usuário autenticado simulado.
-- Tudo em transação com ROLLBACK. Cria membership e papel FICTICIO só dentro da transação.
begin;

do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_user uuid;
  v_mem uuid := gen_random_uuid();
  v_role uuid := gen_random_uuid();
  v_loja uuid := gen_random_uuid(); v_cd uuid := gen_random_uuid();
  v_end_cd uuid := gen_random_uuid(); v_end_loja uuid := gen_random_uuid();
  v_prod uuid := '55555555-5555-5555-5555-555555555555';
  v_pedido uuid; v_transf uuid; v_res jsonb; v_n integer; v_erro text;
begin
  select id into v_user from public.users where ativo order by created_at limit 1;
  if v_user is null then raise exception 'FALHOU 0: sem usuário ativo para o ensaio'; end if;

  -- Papel e membership FICTICIOS: permissões stock.manage e sales.order
  insert into public.erp_roles (id, tenant_id, key, name, active) values (v_role, v_tenant, 'cd-teste-g6', 'FICTICIO Operador CD G6', true);
  insert into public.erp_role_permissions (tenant_id, role_id, permission_id)
    select v_tenant, v_role, p.id from public.erp_permissions p where p.key in ('stock.manage', 'sales.order') and p.active;
  insert into public.erp_tenant_memberships (id, tenant_id, user_id, status) values (v_mem, v_tenant, v_user, 'active');
  insert into public.erp_membership_roles (tenant_id, membership_id, role_id) values (v_tenant, v_mem, v_role);

  -- Estrutura FICTICIA: CD 45 + loja 55
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_loja, v_tenant, 'FICTICIO-LOJA-G6', 'loja', 'FICTICIO Loja G6');
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_cd, v_tenant, 'FICTICIO-CD-G6', 'cd', 'FICTICIO CD G6');
  insert into public.enderecos (id, tenant_id, local_id, tipo_uso) values (v_end_loja, v_tenant, v_loja, 'venda');
  insert into public.enderecos (id, tenant_id, local_id, zona, rua, box, tipo_uso) values (v_end_cd, v_tenant, v_cd, 'galpao', 'A', 'G6', 'armazenagem');
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd) values (v_tenant, v_prod, v_end_cd, 45);
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd) values (v_tenant, v_prod, v_end_loja, 55);

  -- 1. Sem autenticação: criar pedido deve falhar (fail-closed)
  perform set_config('request.jwt.claims', '', true);
  begin
    perform public.cd_api_criar_pedido(v_tenant, v_cd, 'web', '[{"produto_id":"55555555-5555-5555-5555-555555555555","qtd":60,"preco_unit":15}]'::jsonb);
    raise exception 'FALHOU 1: criou pedido sem autenticação';
  exception when sqlstate '42501' then null;
  end;

  -- A partir daqui, usuário autenticado (membership FICTICIA com papel de operador)
  perform set_config('request.jwt.claims', json_build_object('sub', v_user::text, 'role', 'authenticated')::text, true);

  -- 2. Criar pedido web de 60 un. pela API
  v_res := public.cd_api_criar_pedido(v_tenant, v_cd, 'web', '[{"produto_id":"55555555-5555-5555-5555-555555555555","qtd":60,"preco_unit":15}]'::jsonb);
  v_pedido := (v_res->>'pedido_id')::uuid;
  if v_res->>'status' <> 'aguardando_aprovacao' then raise exception 'FALHOU 2: pedido não criado como aguardando'; end if;

  -- 3. Alocar sem aprovação não reserva; aprovado reserva 45 no CD e cria transferência de 15
  v_res := public.cd_api_alocar_pedido(v_tenant, v_pedido, false);
  if v_res->>'status' <> 'aguardando_aprovacao' then raise exception 'FALHOU 3a: não ficou aguardando'; end if;
  v_res := public.cd_api_alocar_pedido(v_tenant, v_pedido, true);
  if (v_res->>'reservado_cd')::int <> 45 or (v_res->>'transferido_para_cd')::int <> 15 then raise exception 'FALHOU 3b: alocação %', v_res; end if;
  select id into v_transf from public.transferencias where tenant_id = v_tenant and pedido_cd_id = v_pedido;

  -- 4. Coletar antes de receber deve falhar
  begin
    perform public.cd_api_coletar_pedido(v_tenant, v_pedido);
    raise exception 'FALHOU 4: coletou com transferência pendente';
  exception when others then if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 5. Receber, coletar e despachar pela API
  v_res := public.cd_api_receber_transferencia(v_tenant, v_transf);
  if v_res->>'status' <> 'recebida' then raise exception 'FALHOU 5a: não recebida'; end if;
  v_res := public.cd_api_coletar_pedido(v_tenant, v_pedido);
  if v_res->>'status' <> 'coletado' then raise exception 'FALHOU 5b: não coletado'; end if;
  v_res := public.cd_api_despachar_pedido(v_tenant, v_pedido);
  if v_res->>'status' <> 'despachado' then raise exception 'FALHOU 5c: não despachado'; end if;

  -- 6. Usuário sem membership no tenant não passa (outro sub autenticado)
  perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid()::text, 'role', 'authenticated')::text, true);
  begin
    perform public.cd_api_alocar_pedido(v_tenant, v_pedido, true);
    raise exception 'FALHOU 6: usuário sem membership alocou';
  exception when sqlstate '42501' then null;
  end;

  -- 7. Capacidade suspensa bloqueia a API mesmo com permissão
  perform set_config('request.jwt.claims', json_build_object('sub', v_user::text, 'role', 'authenticated')::text, true);
  update public.erp_tenant_capabilities set status = 'suspended' where tenant_id = v_tenant and capability_key = 'cd.armazenagem';
  begin
    perform public.cd_api_criar_pedido(v_tenant, v_cd, 'web', '[{"produto_id":"55555555-5555-5555-5555-555555555555","qtd":1,"preco_unit":15}]'::jsonb);
    raise exception 'FALHOU 7: criou pedido com capacidade suspensa';
  exception when sqlstate '42501' then null;
  end;
  update public.erp_tenant_capabilities set status = 'active' where tenant_id = v_tenant and capability_key = 'cd.armazenagem';

  -- 8. Saldo final: loja 55 - 15 = 40 disponível; CD zerado
  select sum(qtd - reservado) into v_n from public.saldos where tenant_id = v_tenant and produto_id = v_prod;
  if v_n <> 40 then raise exception 'FALHOU 8: disponível total diferente de 40 (%)', v_n; end if;

  raise notice 'OK 0060: 8 de 8 verificações passaram (API: criar, alocar, receber, coletar, despachar; bloqueios: sem auth, sem membership, capacidade suspensa)';
end $$;

rollback;
