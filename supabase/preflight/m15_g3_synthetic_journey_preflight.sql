do $$
declare v_missing text;
begin
  if current_setting('server_version_num')::integer < 150000 then raise exception 'PostgreSQL 15+ required'; end if;
  select string_agg(name, ', ' order by name) into v_missing
  from unnest(array['tenants','erp_establishments','erp_parties','erp_units','erp_catalog_items','erp_stock_locations','erp_stock_movements','erp_sales','erp_cash_registers','erp_financial_accounts','erp_financial_entries','erp_fiscal_documents']) as required(name)
  where to_regclass(format('public.%I', required.name)) is null;
  if v_missing is not null then raise exception 'M15_G3_REQUIRED_OBJECTS_MISSING: %', v_missing; end if;
  if to_regclass('supabase_migrations.schema_migrations') is null then raise exception 'MIGRATION_HISTORY_MISSING'; end if;
  if exists(select 1 from unnest(array['0016','0018','0021','0022','0023','0024','0030','0031']) as required(version) where not exists(select 1 from supabase_migrations.schema_migrations h where h.version=required.version)) then raise exception 'M15_G3_REQUIRED_MIGRATION_MISSING'; end if;
  if exists(select 1 from public.tenants where slug like 'm15-g3-synthetic-%') then raise exception 'M15_G3_STALE_FIXTURES_FOUND'; end if;
end$$;
select now() checked_at, 'M15_G3_PREFLIGHT_OK' result;
