begin transaction read only;
do $$begin
  if not exists(select 1 from supabase_migrations.schema_migrations where version='0034')then raise exception 'M18_G20_0034_REQUIRED';end if;
  if exists(select 1 from public.tenants where slug='maniademodas'or lower(dominio)='maniademoda.connectioncyber.com.br')then raise exception 'M18_G20_TENANT_ALREADY_EXISTS';end if;
  if exists(select 1 from public.erp_auth_invitation_outbox)or exists(select 1 from public.erp_auth_identity_compensations)or exists(select 1 from public.erp_identity_provisioning_runs where idempotency_key like'pilot:staging:m18-%')then raise exception 'M18_G20_PROVISIONING_STATE_NOT_EMPTY';end if;
  if to_regprocedure('public.erp_prepare_pilot_provisioning_v1(jsonb)')is null or to_regprocedure('public.erp_record_pilot_auth_identity_v1(uuid,uuid)')is null or to_regprocedure('public.erp_finalize_pilot_identity_v1(uuid,uuid)')is null then raise exception 'M18_G20_RPC_MISSING';end if;
end$$;
rollback;
select 'M18_G20_REMOTE_PREFLIGHT_OK' as marker;
