do $$
begin
  if to_regclass('public.erp_catalog_items') is null
     or to_regprocedure('erp_security.has_permission(uuid,text)') is null
     or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'M20_PREFLIGHT: fundações M02/M05 incompletas.';
  end if;
  if to_regclass('public.erp_item_fiscal_data') is not null
     or to_regclass('public.erp_item_commercial_data') is not null then
    raise exception 'M20_PREFLIGHT: objetos M20-G1 já existem.';
  end if;
  if exists (select 1 from public.erp_permissions where key in ('fiscal.item.read','fiscal.item.manage')) then
    raise exception 'M20_PREFLIGHT: permissões fiscal.item.* já existem.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version='0037') then
    raise exception 'M20_PREFLIGHT: migration 0037 já aplicada.';
  end if;
end $$;
select 'M20_G1_PREFLIGHT_OK' as result, now() as checked_at;
