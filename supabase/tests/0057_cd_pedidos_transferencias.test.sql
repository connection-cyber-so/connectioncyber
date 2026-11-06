-- 0057 teste. Tudo dentro de transação com ROLLBACK: não deixa dado.
-- Dados de teste marcados FICTICIO. Rodar só em staging, depois de aplicar a 0057.
begin;

do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';
  v_loja uuid := gen_random_uuid();
  v_cd uuid := gen_random_uuid();
  v_pedido uuid := gen_random_uuid();
  v_pedido2 uuid := gen_random_uuid();
  v_end uuid := gen_random_uuid();
  v_prod uuid := '22222222-2222-2222-2222-222222222222';
begin
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_loja, v_tenant, 'FICTICIO-LOJA-G3', 'loja', 'FICTICIO Loja G3');
  insert into public.locais (id, tenant_id, codigo, tipo, nome) values (v_cd, v_tenant, 'FICTICIO-CD-G3', 'cd', 'FICTICIO CD G3');
  insert into public.enderecos (id, tenant_id, local_id, zona, rua, box, tipo_uso) values (v_end, v_tenant, v_cd, 'galpao', 'A', 'G3', 'armazenagem');

  -- 1. Pedido do CD fora de local tipo cd deve falhar
  begin
    insert into public.pedidos_cd (tenant_id, local_id, canal) values (v_tenant, v_loja, 'balcao');
    raise exception 'FALHOU 1: pedido aceito em loja';
  exception when others then
    if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 2. Pedido web no CD entra aguardando_aprovacao
  insert into public.pedidos_cd (id, tenant_id, local_id, canal, total_qtd, total_valor) values (v_pedido, v_tenant, v_cd, 'web', 60, 900.00);
  if (select status from public.pedidos_cd where id = v_pedido) <> 'aguardando_aprovacao' then
    raise exception 'FALHOU 2: status padrão diferente de aguardando_aprovacao';
  end if;

  -- 3. Transferência loja → cd aceita; cd → loja falha
  insert into public.transferencias (id, tenant_id, origem_local_id, destino_local_id, pedido_cd_id)
    values (gen_random_uuid(), v_tenant, v_loja, v_cd, v_pedido);
  begin
    insert into public.transferencias (tenant_id, origem_local_id, destino_local_id) values (v_tenant, v_cd, v_loja);
    raise exception 'FALHOU 3: transferência cd → loja aceita';
  exception when others then
    if sqlerrm like 'FALHOU%' then raise; end if;
  end;

  -- 4. Coleta sem autorização deve falhar
  begin
    update public.pedidos_cd set coletado_em = now() where id = v_pedido;
    raise exception 'FALHOU 4: coleta sem autorização aceita';
  exception when check_violation then null;
  end;

  -- 5. Reserva com qtd 0 deve falhar
  begin
    insert into public.reservas (tenant_id, pedido_cd_id, produto_id, endereco_id, qtd) values (v_tenant, v_pedido, v_prod, v_end, 0);
    raise exception 'FALHOU 5: reserva com qtd 0 aceita';
  exception when check_violation then null;
  end;

  -- 6. Reserva válida
  insert into public.reservas (tenant_id, pedido_cd_id, produto_id, endereco_id, qtd) values (v_tenant, v_pedido, v_prod, v_end, 10);

  -- 7. Canal inválido em regras de saída deve falhar
  begin
    insert into public.regras_saida (tenant_id, canal, prioridade, local_tipo) values (v_tenant, 'site', 1, 'cd');
    raise exception 'FALHOU 7: canal inválido aceito';
  exception when check_violation then null;
  end;

  -- 8. Configuração padrão do CD: 50 un. e R$ 2.000
  insert into public.cd_configuracoes (tenant_id) values (v_tenant);
  if (select limite_automatico_qtd || ':' || limite_automatico_valor from public.cd_configuracoes where tenant_id = v_tenant) <> '50:2000.00' then
    raise exception 'FALHOU 8: defaults de limite diferentes de 50 / 2000.00';
  end if;

  raise notice 'OK 0057: 8 de 8 verificações passaram';
end $$;

rollback;
