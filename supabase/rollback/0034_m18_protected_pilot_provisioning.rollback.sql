begin;
do $$begin
  if current_setting('app.confirm_0034_rollback',true)<>'M18_0034_EMPTY_ONLY' then raise exception '0034 rollback confirmation missing';end if;
  if exists(select 1 from public.erp_auth_invitation_outbox)or exists(select 1 from public.erp_auth_identity_compensations)then raise exception '0034 rollback requires empty tables';end if;
end$$;
drop function public.erp_schedule_pilot_auth_compensation_v1(uuid,text);
drop function public.erp_finalize_pilot_identity_v1(uuid,uuid);
drop function public.erp_record_pilot_auth_identity_v1(uuid,uuid);
drop function public.erp_prepare_pilot_provisioning_v1(jsonb);
drop table public.erp_auth_identity_compensations;
drop table public.erp_auth_invitation_outbox;
drop index public.tenants_domain_unique;
drop index public.erp_establishments_tenant_state_registration_unique;
alter table public.erp_establishments drop constraint erp_establishments_state_registration_format,drop column state_registration;
alter table public.erp_identity_provisioning_steps drop constraint erp_identity_provisioning_steps_action_check,add constraint erp_identity_provisioning_steps_action_check check(action in('validate_identity','create_auth_identity','upsert_profile','upsert_membership','assign_roles','require_mfa','write_audit'));
commit;
