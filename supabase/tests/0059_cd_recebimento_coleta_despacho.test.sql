-- 0059 teste ponta a ponta com dado 100% FICTICIO. Tudo em transação com ROLLBACK.
-- Cenário: CD 45 + loja 55; web 60 un. (aprovado: CD 45 + transferência 15); balcão 10 un. na loja.
begin;

do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_loja uuid := gen_random_uuid(); v_cd uuid := gen_random_uuid();
  v_end_cd uuid := gen_random_uuid(); v_end_loja uuid := gen_random_uuid();
  v_web uuid := gen_random_uuid(); v_balcao uuid := gen_random_uuid();
  v_prod uuid := '44444444-4444-4444-4444-444444444444';
  v_res jsonb; v_transf uuid; v_n integer;
begin
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_loja, v_tenant, 'FICTICIO-LOJA-G5', 'loja', 'FICTICIO Loja G5');
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_cd, v_tenant, 'FICTICIO-CD-G5', 'cd', 'FICTICIO CD G5');
  insert into public.enderecos (id, tenant_id, local_id, tipo_uso) values (v_end_loja, v_tenant, v_loja, 'venda');
  insert into public.enderecos (id, tenant_id, local_id, zona, rua, box, tipo_uso) values (v_end_cd, v_tenant, v_cd, 'galpao', 'A', 'G5', 'armazenagem');
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd) values (v_tenant, v_prod, v_end_cd, 45);
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd) values (v_tenant, v_prod, v_end_loja, 55);

  insert into public.pedidos_cd (id, tenant_id, local_id, canal) values (v_web, v_tenant, v_cd, 'web');
  insert into public.pedidos_cd_itens (tenant_id, pedido_cd_id, produto_id, qtd, preco_unit) values (v_tenant, v_web, v_prod, 60, 15.00);
  perform public.cd_alocar_pedido(v_tenant, v_web, true);

  insert into public.pedidos_cd (id, tenant_id, local_id, canal) values (v_balcao, v_tenant, v_cd, 'balcao');
  insert into public.pedidos_cd_itens (tenant_id, pedido_cd_id, produto_id, qtd, preco_unit) values (v_tenant, v_balcao, v_prod, 10, 15.00);
  perform public.cd_alocar_pedido(v_tenant, v_balcao, false);

  select id into v_transf from public.transferencias where tenant_id = v_tenant and pedido_cd_id = v_web;

  -- 1. Coleta antes de receber a transferência deve falhar
  begin
    perform public.cd_coletar_pedido(v_tenant, v_web);
    raise exception 'FALHOU 1: coleta aceita com transferência pendente';
  exception when others then
    if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 2. Recebimento: loja sai 15 (qtd e reservado); CD entra 15 e reserva do pedido passa para o CD
  v_res := public.cd_receber_transferencia(v_tenant, v_transf);
  if v_res->>'status' <> 'recebida' then raise exception 'FALHOU 2: transferência não recebida'; end if;
  if (select qtd from public.saldos where endereco_id = v_end_loja and produto_id = v_prod) <> 40 then raise exception 'FALHOU 2a: loja qtd diferente de 40'; end if;
  if (select reservado from public.saldos where endereco_id = v_end_loja and produto_id = v_prod) <> 10 then raise exception 'FALHOU 2b: loja reservado diferente de 10 (balcão)'; end if;
  if (select qtd from public.saldos where endereco_id = v_end_cd and produto_id = v_prod) <> 60 then raise exception 'FALHOU 2c: CD qtd diferente de 60'; end if;
  if (select reservado from public.saldos where endereco_id = v_end_cd and produto_id = v_prod) <> 60 then raise exception 'FALHOU 2d: CD reservado diferente de 60'; end if;

  -- 3. Receber de novo deve falhar
  begin
    perform public.cd_receber_transferencia(v_tenant, v_transf);
    raise exception 'FALHOU 3: transferência recebida duas vezes';
  exception when others then
    if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 4. Coleta do web: CD dá baixa de 60 (qtd e reservado zerados)
  v_res := public.cd_coletar_pedido(v_tenant, v_web);
  if v_res->>'status' <> 'coletado' then raise exception 'FALHOU 4: web não coletado'; end if;
  if (select qtd from public.saldos where endereco_id = v_end_cd and produto_id = v_prod) <> 0
     or (select reservado from public.saldos where endereco_id = v_end_cd and produto_id = v_prod) <> 0 then
    raise exception 'FALHOU 4b: baixa do CD diferente de 0/0';
  end if;

  -- 5. Despacho do balcão (sem CD): loja dá baixa de 10
  v_res := public.cd_despachar_pedido(v_tenant, v_balcao);
  if v_res->>'status' <> 'despachado' then raise exception 'FALHOU 5: balcão não despachado'; end if;
  if (select qtd from public.saldos where endereco_id = v_end_loja and produto_id = v_prod) <> 30
     or (select reservado from public.saldos where endereco_id = v_end_loja and produto_id = v_prod) <> 0 then
    raise exception 'FALHOU 5b: baixa da loja diferente de 30/0';
  end if;

  -- 6. Despachar o balcão de novo deve falhar
  begin
    perform public.cd_despachar_pedido(v_tenant, v_balcao);
    raise exception 'FALHOU 6: balcão despachado duas vezes';
  exception when others then
    if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 7. Disponível total no fim = 30 (loja) + 0 (CD)
  select sum(qtd - reservado) into v_n from public.saldos where tenant_id = v_tenant and produto_id = v_prod;
  if v_n <> 30 then raise exception 'FALHOU 7: disponível total diferente de 30 (%)', v_n; end if;

  raise notice 'OK 0059: 7 de 7 verificações passaram (loja 30, CD 0, disponível 30)';
end $$;

rollback;
