begin;
drop function if exists public.erp_set_tenant_branding(uuid, text, text);
delete from public.erp_role_permissions
  where permission_id = (select id from public.erp_permissions where key = 'branding.manage');
delete from public.erp_permissions where key = 'branding.manage';
drop table if exists public.erp_tenant_branding;
commit;
