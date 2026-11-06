-- 0055 teste (pgTAP-like com DO/RAISE). Tudo dentro de transação com ROLLBACK: não deixa dado.
-- Dados de teste marcados FICTICIO. Rodar só em staging, depois de aplicar a 0055.
begin;

do $$
declare
  v_tenant uuid := '00000000-0000-0000-0000-000000000001';  -- Nuvem de Papel (staging)
  v_loja uuid := gen_random_uuid();
  v_cd uuid := gen_random_uuid();
  v_end_loja uuid := gen_random_uuid();
  v_box uuid := gen_random_uuid();
  v_erro text;
begin
  -- 1. Locais válidos
  insert into public.locais (id, tenant_id, codigo, tipo, nome)
    values (v_loja, v_tenant, 'FICTICIO-LOJA', 'loja', 'FICTICIO Loja');
  insert into public.locais (id, tenant_id, codigo, tipo, nome)
    values (v_cd, v_tenant, 'FICTICIO-CD', 'cd', 'FICTICIO CD');

  -- 2. Loja aceita endereço de venda
  insert into public.enderecos (id, tenant_id, local_id, tipo_uso)
    values (v_end_loja, v_tenant, v_loja, 'venda');

  -- 3. CD aceita box com zona, rua e box
  insert into public.enderecos (id, tenant_id, local_id, zona, rua, box, tipo_uso, capacidade_posicoes)
    values (v_box, v_tenant, v_cd, 'galpao', 'A', '12', 'armazenagem', 40);

  -- 4. Endereço de venda dentro do CD deve falhar
  begin
    insert into public.enderecos (tenant_id, local_id, tipo_uso)
      values (v_tenant, v_cd, 'venda');
    raise exception 'FALHOU: venda aceita em CD';
  exception when others then
    v_erro := sqlerrm;
    if v_erro like 'FALHOU%' then raise; end if;
  end;

  -- 5. Box de armazenagem dentro da loja deve falhar
  begin
    insert into public.enderecos (tenant_id, local_id, zona, rua, box, tipo_uso)
      values (v_tenant, v_loja, 'salao', 'B', '1', 'armazenagem');
    raise exception 'FALHOU: armazenagem aceita em loja';
  exception when others then
    v_erro := sqlerrm;
    if v_erro like 'FALHOU%' then raise; end if;
  end;

  -- 6. Reservado maior que qtd deve falhar
  begin
    insert into public.saldos (tenant_id, produto_id, endereco_id, qtd, reservado)
      values (v_tenant, gen_random_uuid(), v_box, 5, 6);
    raise exception 'FALHOU: reservado > qtd aceito';
  exception when check_violation then
    null;
  end;

  -- 7. Saldo válido e disponível = Σ(qtd − reservado)
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd, reservado)
    values (v_tenant, '11111111-1111-1111-1111-111111111111', v_box, 45, 2);
  insert into public.saldos (tenant_id, produto_id, endereco_id, qtd, reservado)
    values (v_tenant, '11111111-1111-1111-1111-111111111111', v_end_loja, 55, 0);

  if (select sum(qtd - reservado) from public.saldos
      where tenant_id = v_tenant and produto_id = '11111111-1111-1111-1111-111111111111') <> 98 then
    raise exception 'FALHOU: disponível diferente de 98 (45-2 + 55-0)';
  end if;

  -- 8. Endereço duplicado (mesma rua e box no mesmo local) deve falhar
  begin
    insert into public.enderecos (tenant_id, local_id, zona, rua, box, tipo_uso)
      values (v_tenant, v_cd, 'salao', 'A', '12', 'separacao');
    raise exception 'FALHOU: box duplicado aceito';
  exception when unique_violation then
    null;
  end;

  raise notice 'OK 0055: 8 de 8 verificações passaram';
end $$;

rollback;
