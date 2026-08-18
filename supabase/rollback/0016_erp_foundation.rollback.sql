-- ConnectionCyber — M02 — rollback destrutivo SOMENTE para laboratório descartável
--
-- NÃO executar em Supabase staging após receber qualquer dado de tenant.
-- NÃO executar em produção.
-- Em ambiente remoto com dados, corrigir por migration forward-fix (0017+).
--
-- Para liberar conscientemente este script na mesma sessão:
--   set app.execution_environment = 'LOCAL-DISCARDABLE-LAB';
--   set app.m02_rollback_confirmation = 'DROP-M02-WITHOUT-TENANT-DATA';

begin;

do $$
declare
  tenant_row_count bigint;
begin
  if current_setting('app.execution_environment', true)
       is distinct from 'LOCAL-DISCARDABLE-LAB'
     or current_setting('app.m02_rollback_confirmation', true)
       is distinct from 'DROP-M02-WITHOUT-TENANT-DATA' then
    raise exception 'M02_ROLLBACK_BLOCKED: confirmações explícitas ausentes.';
  end if;

  select
      (select count(*) from public.erp_tenant_memberships)
    + (select count(*) from public.erp_roles)
    + (select count(*) from public.erp_role_permissions)
    + (select count(*) from public.erp_membership_roles)
    + (select count(*) from public.erp_establishments)
    + (select count(*) from public.erp_tenant_capabilities)
    + (select count(*) from public.erp_tenant_segment_profiles)
    + (select count(*) from public.erp_tenant_settings)
    + (select count(*) from public.erp_number_sequences)
    + (select count(*) from public.erp_audit_events)
  into tenant_row_count;

  if tenant_row_count <> 0 then
    raise exception
      'M02_ROLLBACK_BLOCKED: % linhas vinculadas a tenant existem; use forward-fix.',
      tenant_row_count;
  end if;
end
$$;

drop function if exists public.erp_next_number(uuid, text, uuid, date);

drop policy if exists erp_roles_select_member_or_staff on public.erp_roles;
drop policy if exists erp_role_permissions_select_member_or_staff on public.erp_role_permissions;
drop policy if exists erp_establishments_select_member_or_staff on public.erp_establishments;
drop policy if exists erp_tenant_capabilities_select_member_or_staff on public.erp_tenant_capabilities;
drop policy if exists erp_tenant_profiles_select_member_or_staff on public.erp_tenant_segment_profiles;
drop policy if exists erp_tenant_settings_select_member_or_staff on public.erp_tenant_settings;
drop policy if exists erp_number_sequences_select_member_or_staff on public.erp_number_sequences;
drop policy if exists erp_audit_select_actor_permission_or_staff on public.erp_audit_events;

drop trigger if exists trg_erp_audit_append_only on public.erp_audit_events;

drop function if exists erp_security.prevent_audit_mutation();
drop function if exists erp_security.next_number(uuid, text, uuid, date);
drop function if exists erp_security.has_permission(uuid, text);
drop function if exists erp_security.is_tenant_member(uuid);

drop table if exists public.erp_audit_events;
drop table if exists public.erp_number_sequences;
drop table if exists public.erp_tenant_settings;
drop table if exists public.erp_tenant_segment_profiles;
drop table if exists public.erp_segment_profile_capabilities;
drop table if exists public.erp_segment_profiles;
drop table if exists public.erp_tenant_capabilities;
drop table if exists public.erp_capability_catalog;
drop table if exists public.erp_establishments;
drop table if exists public.erp_membership_roles;
drop table if exists public.erp_role_permissions;
drop table if exists public.erp_permissions;
drop table if exists public.erp_roles;
drop table if exists public.erp_tenant_memberships;

drop schema if exists erp_security;

commit;
