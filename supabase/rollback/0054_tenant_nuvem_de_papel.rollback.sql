-- Rollback 0054. Recusa se houver membership ou dado operacional do tenant.
begin;
do $$
begin
  if exists (select 1 from public.erp_tenant_memberships where tenant_id = '00000000-0000-0000-0000-000000000001') then
    raise exception 'ROLLBACK_0054_RECUSADO: tenant Nuvem tem memberships. Forward-fix obrigatório.';
  end if;
end $$;
delete from public.erp_tenant_capabilities where tenant_id = '00000000-0000-0000-0000-000000000001';
delete from public.tenant_domains where tenant_id = '00000000-0000-0000-0000-000000000001';
delete from public.tenants where id = '00000000-0000-0000-0000-000000000001';
commit;
