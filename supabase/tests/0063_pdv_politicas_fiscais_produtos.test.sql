-- Testes 0063. Rodar DEPOIS de aplicar a migration 0063, no staging.
-- Fixtures com nomes aleatórios; tudo termina em ROLLBACK: nada persiste.
-- Esperado: nenhuma exceção (NOTICE 'TODOS OS TESTES 0063 PASSARAM').

begin;

do $$
declare
  v_tenant uuid;
  v_estab uuid;
  v_unit uuid;
  v_item uuid;
  v_item_fum uuid;
  v_bloqueou boolean;
  v_constraint text;
  v_settings integer;
  v_tenants integer;
begin
  select e.tenant_id, e.id into v_tenant, v_estab
    from public.erp_establishments e
   order by e.created_at nulls last
   limit 1;
  if v_tenant is null then
    raise notice 'AVISO: staging sem estabelecimento; testes 0063 pulados';
    return;
  end if;

  -- A. Colunas com default false
  perform 1 from information_schema.columns
   where table_schema = 'public' and table_name = 'erp_catalog_items'
     and column_name in ('age_restricted', 'fumigeno') and column_default like '%false%'
   having count(*) = 2;
  if not found then raise exception 'FALHA A: flags sem default false'; end if;

  -- Fixtures de catálogo
  insert into public.erp_units (tenant_id, code, name, dimension, decimal_scale)
  values (v_tenant, upper(substr(md5(random()::text), 1, 10)), 'Unidade teste', 'count', 0)
  returning id into v_unit;

  insert into public.erp_catalog_items (tenant_id, kind, code, name, base_unit_id, allows_fraction)
  values (v_tenant, 'product', 'T' || upper(substr(md5(random()::text), 1, 10)), 'Produto teste', v_unit, false)
  returning id into v_item;

  -- B. Fumígeno sem +18 é bloqueado pela constraint correta
  v_bloqueou := false;
  begin
    insert into public.erp_catalog_items (tenant_id, kind, code, name, base_unit_id, allows_fraction, fumigeno, age_restricted)
    values (v_tenant, 'product', 'T' || upper(substr(md5(random()::text), 1, 10)), 'Fumigeno sem idade', v_unit, false, true, false);
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA B: fumigeno sem +18 aceito'; end if;
  if v_constraint is distinct from 'erp_catalog_items_fumigeno_requires_age_check' then
    raise exception 'FALHA B: bloqueado por outra constraint (%)', v_constraint;
  end if;

  -- C. Fumígeno fracionado é bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_catalog_items (tenant_id, kind, code, name, base_unit_id, allows_fraction, fumigeno, age_restricted)
    values (v_tenant, 'product', 'T' || upper(substr(md5(random()::text), 1, 10)), 'Fumigeno fracionado', v_unit, true, true, true);
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA C: fumigeno fracionado aceito'; end if;
  if v_constraint is distinct from 'erp_catalog_items_fumigeno_no_fraction_check' then
    raise exception 'FALHA C: bloqueado por outra constraint (%)', v_constraint;
  end if;

  -- D. Fumígeno válido (+18, não fracionado) é aceito
  insert into public.erp_catalog_items (tenant_id, kind, code, name, base_unit_id, allows_fraction, fumigeno, age_restricted)
  values (v_tenant, 'product', 'T' || upper(substr(md5(random()::text), 1, 10)), 'Fumigeno valido', v_unit, false, true, true)
  returning id into v_item_fum;

  -- E. Alçada: desconto que não excede o limite é bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_discount_authorizations
      (tenant_id, establishment_id, requested_by, approved_by, discount_amount, discount_percent, limit_percent, reason)
    values (v_tenant, v_estab, gen_random_uuid(), gen_random_uuid(), 5.00, 4.00, 5.00, 'Cliente fiel');
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA E: desconto abaixo do limite aceito'; end if;
  if v_constraint is distinct from 'erp_discount_authorizations_above_limit_check' then
    raise exception 'FALHA E: bloqueado por outra constraint (%)', v_constraint;
  end if;

  -- F. Aprovador igual ao solicitante é bloqueado
  v_bloqueou := false;
  declare v_same uuid := gen_random_uuid();
  begin
    insert into public.erp_discount_authorizations
      (tenant_id, establishment_id, requested_by, approved_by, discount_amount, discount_percent, limit_percent, reason)
    values (v_tenant, v_estab, v_same, v_same, 10.00, 10.00, 5.00, 'Promocao');
  exception when check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA F: aprovador igual ao solicitante aceito'; end if;
  if v_constraint is distinct from 'erp_discount_authorizations_separation_check' then
    raise exception 'FALHA F: bloqueado por outra constraint (%)', v_constraint;
  end if;

  -- G. Motivo curto é bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_discount_authorizations
      (tenant_id, establishment_id, requested_by, approved_by, discount_amount, discount_percent, limit_percent, reason)
    values (v_tenant, v_estab, gen_random_uuid(), gen_random_uuid(), 10.00, 10.00, 5.00, 'ok');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA G: motivo curto aceito'; end if;

  -- H. Autorização válida é aceita
  insert into public.erp_discount_authorizations
    (tenant_id, establishment_id, requested_by, approved_by, discount_amount, discount_percent, limit_percent, reason)
  values (v_tenant, v_estab, gen_random_uuid(), gen_random_uuid(), 10.00, 10.00, 5.00, 'Cortesia de aniversario');

  -- I. Seeds: cada tenant tem as 3 chaves padrão (nível tenant)
  select count(*) into v_settings from public.erp_tenant_settings
   where establishment_id is null
     and key in ('pdv.discount.auto_limit_percent', 'pdv.fiscal.emit_nfce_by_channel', 'pdv.kitchen.print_on_accept');
  select count(*) into v_tenants from public.tenants;
  if v_settings < 3 * v_tenants then
    raise exception 'FALHA I: seeds incompletos (% de % esperados)', v_settings, 3 * v_tenants;
  end if;
end
$$;

rollback;
