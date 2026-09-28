do $$
begin
  if to_regclass('public.erp_item_fiscal_data') is null then
    raise exception 'M20_PREFLIGHT: fundação M20-G1 (erp_item_fiscal_data) incompleta.';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='erp_item_fiscal_data'
      and column_name in ('cst_ibs_cbs','cclass_trib')
  ) then
    raise exception 'M20_PREFLIGHT: colunas da reforma tributária já existem.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version='0039') then
    raise exception 'M20_PREFLIGHT: migration 0039 já aplicada.';
  end if;
end $$;
select 'M20_G5_PREFLIGHT_OK' as result, now() as checked_at;
