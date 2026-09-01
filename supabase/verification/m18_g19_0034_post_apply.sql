begin transaction read only;
do $$begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='0034')then raise exception 'M18_G19_HISTORY_MISSING';end if;
  if to_regclass('public.erp_auth_invitation_outbox')is null or to_regclass('public.erp_auth_identity_compensations')is null then raise exception 'M18_G19_TABLE_MISSING';end if;
  if to_regprocedure('public.erp_prepare_pilot_provisioning_v1(jsonb)')is null or to_regprocedure('public.erp_record_pilot_auth_identity_v1(uuid,uuid)')is null or to_regprocedure('public.erp_finalize_pilot_identity_v1(uuid,uuid)')is null or to_regprocedure('public.erp_schedule_pilot_auth_compensation_v1(uuid,text)')is null then raise exception 'M18_G19_RPC_MISSING';end if;
  if not(select relrowsecurity from pg_class where oid='public.erp_auth_invitation_outbox'::regclass)or not(select relrowsecurity from pg_class where oid='public.erp_auth_identity_compensations'::regclass)then raise exception 'M18_G19_RLS_MISSING';end if;
  if has_table_privilege('anon','public.erp_auth_invitation_outbox','SELECT')or has_table_privilege('authenticated','public.erp_auth_invitation_outbox','SELECT')or has_table_privilege('anon','public.erp_auth_identity_compensations','SELECT')or has_table_privilege('authenticated','public.erp_auth_identity_compensations','SELECT')then raise exception 'M18_G19_CLIENT_PRIVILEGE';end if;
  if exists(select 1 from public.tenants where slug in('maniademodas','m18-g17-synthetic'))or exists(select 1 from public.erp_auth_invitation_outbox)or exists(select 1 from public.erp_auth_identity_compensations)or exists(select 1 from public.erp_identity_provisioning_runs where idempotency_key like'pilot:staging:m18-%')then raise exception 'M18_G19_UNEXPECTED_DATA';end if;
end$$;
rollback;
select 'M18_G19_0034_APPLIED_90_OF_90_ZERO_DATA' as marker;
