do $$
declare n text;
begin
  foreach n in array array['tenants','erp_roles','erp_permissions','erp_role_permissions'] loop
    if to_regclass('public.'||n) is null then raise exception 'missing dependency: %', n; end if;
  end loop;
  if to_regclass('public.erp_tenant_branding') is not null then raise exception '0035 already present'; end if;
  if to_regprocedure('erp_security.is_tenant_member(uuid)') is null
    or to_regprocedure('erp_security.has_permission(uuid,text)') is null
    or to_regprocedure('public.is_platform_staff()') is null
    or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'required baseline function missing';
  end if;
end$$;
select 'M19_0035_PREFLIGHT_OK' as result;
