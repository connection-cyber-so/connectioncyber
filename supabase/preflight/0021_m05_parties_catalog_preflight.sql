do $$
begin
  if to_regclass('public.erp_tenant_memberships') is null
     or to_regclass('public.erp_establishments') is null
     or to_regprocedure('erp_security.has_permission(uuid,text)') is null then
    raise exception 'M05_PREFLIGHT: fundações M02/M04 incompletas.';
  end if;
  if to_regclass('public.erp_parties') is not null or to_regclass('public.erp_catalog_items') is not null then
    raise exception 'M05_PREFLIGHT: objetos M05 já existem.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version='0021') then
    raise exception 'M05_PREFLIGHT: migration 0021 já aplicada.';
  end if;
end $$;
select 'M05_PREFLIGHT_OK' as result, now() as checked_at;
