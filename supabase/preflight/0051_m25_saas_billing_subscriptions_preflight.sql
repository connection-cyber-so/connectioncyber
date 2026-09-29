-- Read-only; 0051 prerequisites: 0050 applied, M25 billing objects still absent.
do $$
begin
  if to_regclass('public.saas_plans') is not null
     or to_regclass('public.saas_plan_capabilities') is not null
     or to_regclass('public.saas_checkout_intents') is not null
     or to_regclass('public.saas_subscriptions') is not null
     or to_regclass('public.saas_billing_events') is not null then
    raise exception 'M25_PREFLIGHT: tabelas M25 ja existem; migration 0051 ja aplicada.';
  end if;
  if to_regprocedure('public.saas_create_checkout_intent_v1(uuid,text,jsonb)') is not null
     or to_regprocedure('public.saas_activate_intent_v1(text,timestamptz)') is not null then
    raise exception 'M25_PREFLIGHT: funcoes M25 ja existem; migration 0051 ja aplicada.';
  end if;
  if exists(select 1 from supabase_migrations.schema_migrations where version = '0051') then
    raise exception 'M25_PREFLIGHT: migration 0051 ja aplicada.';
  end if;
  if to_regclass('public.erp_accountant_packages') is null then
    raise exception 'M25_PREFLIGHT: migration 0050 (M24) nao aplicada.';
  end if;
  if to_regprocedure('public.erp_prepare_pilot_provisioning_v1(jsonb)') is null
     or to_regprocedure('public.erp_record_pilot_auth_identity_v1(uuid,uuid)') is null
     or to_regprocedure('public.erp_finalize_pilot_identity_v1(uuid,uuid)') is null then
    raise exception 'M25_PREFLIGHT: contrato de provisionamento (0034) ausente.';
  end if;
  if to_regclass('public.erp_capability_catalog') is null then
    raise exception 'M25_PREFLIGHT: catalogo de capabilities ausente.';
  end if;
end $$;
select count(*) as historico_ate_0050 from supabase_migrations.schema_migrations
 where version between '0001' and '0050';
-- Marcador por ultimo: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M25_PREFLIGHT_OK' as result, now() as checked_at;
