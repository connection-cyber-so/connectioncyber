-- Read-only; inspect output before apply. academy objects must be absent.
do $$
begin
  if to_regprocedure('erp_security.is_tenant_member(uuid)') is null
     or to_regprocedure('erp_security.has_permission_at_aal(uuid,text,text)') is null
     or to_regclass('public.tenants') is null then
    raise exception 'M23_G0_PREFLIGHT: fundacao ERP (migrations 0016/0018) incompleta.';
  end if;
  if to_regclass('public.academy_courses') is not null
     or to_regclass('public.academy_modules') is not null
     or to_regprocedure('public.academy_command(uuid,text,uuid,jsonb)') is not null then
    raise exception 'M23_G0_PREFLIGHT: objetos academy ja existem; migration 0044 ja aplicada.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0044') then
    raise exception 'M23_G0_PREFLIGHT: migration 0044 ja aplicada.';
  end if;
end $$;
select 'M23_G0_PREFLIGHT_OK' as result, now() as checked_at;
select key,risk_level,active from public.erp_capability_catalog where key='academy.courses';
select key from public.erp_permissions where key like 'academy.%';
-- Catalogo publico legado: evidencia do 42501 que a 0044 corrige com grants.
select has_table_privilege('anon','public.courses','select') as anon_courses_select,
       has_table_privilege('anon','public.products','select') as anon_products_select,
       has_table_privilege('anon','public.cms_content','select') as anon_cms_select;
