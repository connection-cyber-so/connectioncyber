do $$
begin
  if to_regclass('public.erp_tenant_memberships') is null then raise exception 'missing dependency: erp_tenant_memberships'; end if;
  if to_regprocedure('public.erp_accept_pending_memberships_v1()') is not null then raise exception '0036 already present'; end if;
end$$;
select 'M18_0036_PREFLIGHT_OK' as result;
