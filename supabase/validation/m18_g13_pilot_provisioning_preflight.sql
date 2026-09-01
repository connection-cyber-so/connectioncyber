begin transaction read only;

do $$
begin
  if exists (
    select 1 from public.tenants
    where slug = 'maniademodas'
       or dominio = 'maniademoda.connectioncyber.com.br'
  ) then
    raise exception 'M18_G13_PILOT_ALREADY_EXISTS';
  end if;

  if (
    select count(*) from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'tenants', 'users', 'erp_tenant_memberships', 'erp_roles',
        'erp_membership_roles', 'erp_establishments',
        'erp_identity_provisioning_runs', 'erp_identity_provisioning_steps'
      )
      and c.relkind = 'r'
  ) <> 8 then
    raise exception 'M18_G13_REQUIRED_TABLES_MISSING';
  end if;

  if exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('tenants', 'users', 'erp_tenant_memberships', 'erp_roles', 'erp_membership_roles', 'erp_establishments')
      and not c.relrowsecurity
  ) then
    raise exception 'M18_G13_RLS_NOT_ENABLED';
  end if;

  if not exists (select 1 from public.erp_permissions where key = 'identities.read')
     or not exists (select 1 from public.erp_permissions where key = 'identities.manage')
     or not exists (select 1 from public.erp_permissions where key = 'mfa.enforce') then
    raise exception 'M18_G13_REQUIRED_PERMISSIONS_MISSING';
  end if;
end
$$;

rollback;

select 'M18_G13_PILOT_PREFLIGHT_OK' as marker;
