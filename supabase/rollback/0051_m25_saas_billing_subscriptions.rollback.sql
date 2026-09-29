-- Rollback da migration 0051 (M25-G0). Nao altera objetos de outras migracoes.
begin;

drop function if exists public.saas_mark_billing_event_processed_v1(text, text, text);
drop function if exists public.saas_record_billing_event_v1(text, text, text, text, text, jsonb);
drop function if exists public.saas_set_subscription_status_v1(text, text, text);
drop function if exists public.saas_activate_intent_v1(text, timestamptz);
drop function if exists public.saas_bind_preapproval_v1(uuid, text, text);
drop function if exists public.saas_create_checkout_intent_v1(uuid, text, jsonb);

drop table if exists public.saas_billing_events;
drop table if exists public.saas_subscriptions;
drop table if exists public.saas_checkout_intents;
drop table if exists public.saas_plan_capabilities;
drop table if exists public.saas_plans;

commit;
