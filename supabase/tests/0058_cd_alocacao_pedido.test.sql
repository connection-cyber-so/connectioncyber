-- 0058 teste ponta a ponta com dado 100% FICTICIO. Tudo em transação com ROLLBACK: não deixa dado.
-- Cenário: CD tem 45 do produto FICTICIO; loja tem 55. Pedido web de 60 un. (acima do limite de 50).
begin;

do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_loja uuid := gen_random_uuid();
  v_cd uuid := gen_random_uuid();
  v_end_cd uuid := gen_random_uuid();
  v_end_loja uuid := gen_random_uuid();
  v_pedido uuid := gen_random_uuid();
  v_pedido_balcao uuid := gen_random_uuid();
  v_prod uuid := '33333333-3333-3333-3333-333333333333';
  v_res jsonb;
  v_n integer;
begin
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_loja, v_tenant, 'FICTICIO-LOJA-G4', 'loja', 'FICTICIO Loja G4');
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_cd, v_tenant, 'FICTICIO-CD-G4', 'cd', 'FICTICIO CD G4');
  insert into public.enderecos (id, tenant_id, local_id, tipo_uso) values (v_end_loja, v_tenant, v_loja, 'venda');
  insert into public.enderecos (id, tenant_id, local_id, zona, rua, box, tipo_uso) values (v_end_cd, v_tenant, v_cd, 'galpao', 'A', 'G4', 'armazenagem');
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd) values (v_tenant, v_prod, v_end_cd, 45);
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd) values (v_tenant, v_prod, v_end_loja, 55);

  insert into public.pedidos_cd (id, tenant_id, local_id, canal) values (v_pedido, v_tenant, v_cd, 'web');
  insert into public.pedidos_cd_itens (tenant_id, pedido_cd_id, produto_id, qtd, preco_unit) values (v_tenant, v_pedido, v_prod, 60, 15.00);

  -- 1. Acima do limite (60 > 50) sem aprovação: não reserva nada
  v_res := public.cd_alocar_pedido(v_tenant, v_pedido, false);
  if v_res->>'status' <> 'aguardando_aprovacao' then raise exception 'FALHOU 1: pedido de 60 un. não ficou aguardando'; end if;
  if (select count(*) from public.reservas where pedido_cd_id = v_pedido) <> 0 then raise exception 'FALHOU 1b: reservou sem aprovação'; end if;

  -- 2. Com aprovação: CD reserva 45, falta 15 vira transferência loja → CD
  v_res := public.cd_alocar_pedido(v_tenant, v_pedido, true);
  if v_res->>'status' <> 'autorizada' then raise exception 'FALHOU 2: pedido não autorizado após aprovação'; end if;
  if (v_res->>'reservado_cd')::int <> 45 or (v_res->>'transferido_para_cd')::int <> 15 or (v_res->>'falta_sem_cobertura')::int <> 0 then
    raise exception 'FALHOU 2b: alocação diferente de 45/15/0: %', v_res;
  end if;
  if (select qtd from public.saldos where endereco_id = v_end_cd and produto_id = v_prod) <> 45
     or (select reservado from public.saldos where endereco_id = v_end_cd and produto_id = v_prod) <> 45 then
    raise exception 'FALHOU 2c: saldo do CD diferente de 45/45';
  end if;
  if (select count(*) from public.transferencias t join public.transferencia_itens i on i.transferencia_id = t.id
      where t.pedido_cd_id = v_pedido and t.origem_local_id = v_loja and t.destino_local_id = v_cd and t.status = 'pendente' and i.qtd = 15) <> 1 then
    raise exception 'FALHOU 2d: transferência loja → CD de 15 não criada';
  end if;

  -- 3. Pedido já alocado não pode ser alocado de novo
  begin
    perform public.cd_alocar_pedido(v_tenant, v_pedido, true);
    raise exception 'FALHOU 3: pedido alocado duas vezes';
  exception when others then
    if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 4. Balcão (só loja nas regras): reserva direto na loja, sem CD e sem transferência
  insert into public.pedidos_cd (id, tenant_id, local_id, canal) values (v_pedido_balcao, v_tenant, v_cd, 'balcao');
  insert into public.pedidos_cd_itens (tenant_id, pedido_cd_id, produto_id, qtd, preco_unit) values (v_tenant, v_pedido_balcao, v_prod, 10, 15.00);
  v_res := public.cd_alocar_pedido(v_tenant, v_pedido_balcao, false);
  if v_res->>'status' <> 'autorizada' or (v_res->>'reservado_cd')::int <> 0 then
    raise exception 'FALHOU 4: balcão deveria autorizar sem reservar no CD';
  end if;

  -- 5. Saldos finais: loja reservada = 15 (transferência) + 10 (balcão) = 25; disponível da loja = 30
  if (select reservado from public.saldos where endereco_id = v_end_loja and produto_id = v_prod) <> 25 then
    raise exception 'FALHOU 5: reservado da loja diferente de 25';
  end if;
  select sum(qtd - reservado) into v_n from public.saldos where tenant_id = v_tenant and produto_id = v_prod;
  if v_n <> 30 then raise exception 'FALHOU 5b: disponível total diferente de 30 (%)', v_n; end if;

  raise notice 'OK 0058: 5 de 5 verificações passaram (CD 45/45, transferência 15, balcão 10, disponível 30)';
end $$;

rollback;
