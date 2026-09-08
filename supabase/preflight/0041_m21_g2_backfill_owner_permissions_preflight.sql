do $$
begin
  if to_regclass('public.erp_role_permissions') is null or to_regclass('public.erp_roles') is null then
    raise exception 'M21_G2_PREFLIGHT: fundação M16 (erp_roles/erp_role_permissions) incompleta.';
  end if;
  if not exists (select 1 from public.erp_permissions where key = 'establishments.manage') then
    raise exception 'M21_G2_PREFLIGHT: migration 0040 (establishments.manage) ainda não aplicada.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0041') then
    raise exception 'M21_G2_PREFLIGHT: migration 0041 já aplicada.';
  end if;
end $$;
select 'M21_G2_PREFLIGHT_OK' as result, now() as checked_at;
