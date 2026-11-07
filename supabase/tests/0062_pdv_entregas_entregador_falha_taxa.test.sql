-- Testes 0062. Rodar DEPOIS de aplicar a migration 0062, no staging.
-- Tudo dentro de transação com ROLLBACK: nada persiste.
-- Tenant e estabelecimento são escolhidos dinamicamente do próprio staging (não há id fixo).
-- Esperado: nenhuma exceção; NOTICE 'TODOS OS TESTES 0062 PASSARAM' no fim.

begin;

do $$
declare
  v_tenant uuid;
  v_estab uuid;
  v_tab uuid;
  v_zone_a uuid;
  v_overlap_blocked boolean := false;
  v_fee_negativa_rejeitada boolean := false;
  v_motivo_obrigatorio boolean := false;
  v_constraint text;
begin
  -- A. Defaults das colunas novas
  perform 1 from information_schema.columns
   where table_schema = 'public' and table_name = 'erp_food_fulfillments'
     and column_name = 'fee_charge_mode' and column_default like '%in_sale%';
  if not found then raise exception 'FALHA A: default de fee_charge_mode'; end if;

  -- B. Check de status inclui 'failed'
  perform 1 from pg_constraint
   where conname = 'erp_food_fulfillments_status_check'
     and pg_get_constraintdef(oid) like '%failed%';
  if not found then raise exception 'FALHA B: status check sem failed'; end if;

  -- C. Zonas de taxa (usa o primeiro estabelecimento existente)
  select e.tenant_id, e.id into v_tenant, v_estab
    from public.erp_establishments e
   order by e.created_at nulls last
   limit 1;

  if v_estab is null then
    raise notice 'AVISO C: staging sem estabelecimento; testes de zona pulados';
  else
    insert into public.erp_delivery_fee_zones (tenant_id, establishment_id, radius_from_km, radius_to_km, fee_amount)
    values (v_tenant, v_estab, 0, 3, 5.00) returning id into v_zone_a;

    -- C2. Faixa sobreposta deve ser bloqueada
    begin
      insert into public.erp_delivery_fee_zones (tenant_id, establishment_id, radius_from_km, radius_to_km, fee_amount)
      values (v_tenant, v_estab, 2, 6, 8.00);
    exception when sqlstate '23P01' then
      v_overlap_blocked := true;
    end;
    if not v_overlap_blocked then raise exception 'FALHA C2: sobreposicao nao bloqueada'; end if;

    -- C3. Faixa encostada [3,6) é permitida
    insert into public.erp_delivery_fee_zones (tenant_id, establishment_id, radius_from_km, radius_to_km, fee_amount)
    values (v_tenant, v_estab, 3, 6, 8.00);

    -- C4. Taxa negativa é rejeitada
    begin
      insert into public.erp_delivery_fee_zones (tenant_id, establishment_id, radius_from_km, radius_to_km, fee_amount)
      values (v_tenant, v_estab, 6, 9, -1.00);
    exception when check_violation then
      v_fee_negativa_rejeitada := true;
    end;
    if not v_fee_negativa_rejeitada then raise exception 'FALHA C4: taxa negativa aceita'; end if;
  end if;

  -- D. Comanda de teste criada dentro da transação (staging não tem comandas reais)
  insert into public.erp_food_tabs (tenant_id, establishment_id, code, channel, idempotency_key)
  values (v_tenant, v_estab, 'T' || upper(substr(md5(random()::text), 1, 8)), 'delivery', 'teste-0062-' || gen_random_uuid())
  returning id into v_tab;

  -- D1. Falha sem motivo deve ser bloqueada PELA constraint de motivo (não por outro check)
  begin
    insert into public.erp_food_fulfillments (tenant_id, food_tab_id, kind, status, idempotency_key)
    values (v_tenant, v_tab, 'delivery', 'failed', 'teste-0062-sem-motivo-' || gen_random_uuid());
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    v_motivo_obrigatorio := true;
  end;
  if not v_motivo_obrigatorio then raise exception 'FALHA D1: falha sem motivo foi aceita'; end if;
  if v_constraint is distinct from 'erp_food_fulfillments_failure_reason_check' then
    raise exception 'FALHA D1: bloqueada por outra constraint (%), nao pela de motivo', v_constraint;
  end if;

  -- D2. Falha com motivo e horário deve ser aceita
  insert into public.erp_food_fulfillments
    (tenant_id, food_tab_id, kind, status, idempotency_key, failure_reason, failed_at)
  values (v_tenant, v_tab, 'delivery', 'failed', 'teste-0062-com-motivo-' || gen_random_uuid(), 'Endereco nao localizado', now());

  raise notice 'TODOS OS TESTES 0062 PASSARAM';
end
$$;

rollback;
