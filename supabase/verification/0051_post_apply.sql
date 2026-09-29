-- M25 post-apply verification (read-only): run after applying 0051.
select to_regclass('public.saas_plans') as planos,
       to_regclass('public.saas_plan_capabilities') as plan_caps,
       to_regclass('public.saas_checkout_intents') as intents,
       to_regclass('public.saas_subscriptions') as assinaturas,
       to_regclass('public.saas_billing_events') as eventos;
select to_regprocedure('public.saas_create_checkout_intent_v1(uuid,text,jsonb)') as rpc_intent,
       to_regprocedure('public.saas_bind_preapproval_v1(uuid,text,text)') as rpc_bind,
       to_regprocedure('public.saas_activate_intent_v1(text,timestamptz)') as rpc_activate,
       to_regprocedure('public.saas_set_subscription_status_v1(text,text,text)') as rpc_status,
       to_regprocedure('public.saas_record_billing_event_v1(text,text,text,text,text,jsonb)') as rpc_event,
       to_regprocedure('public.saas_mark_billing_event_processed_v1(text,text,text)') as rpc_mark;
select count(*) as planos_seed from public.saas_plans where code = 'padrao' and active and price_cents = 19900;
select count(*) as capabilities_seed from public.saas_plan_capabilities pc
 join public.saas_plans p on p.id = pc.plan_id where p.code = 'padrao';
select c.relname, c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname in
 ('saas_plans','saas_plan_capabilities','saas_checkout_intents','saas_subscriptions','saas_billing_events')
 order by c.relname;
select has_table_privilege('anon','public.saas_plans','select') as anon_plans_select_must_be_true,
       has_table_privilege('anon','public.saas_subscriptions','select') as anon_subs_select_must_be_false,
       has_function_privilege('anon','public.saas_activate_intent_v1(text,timestamptz)','execute') as anon_activate_must_be_false,
       has_function_privilege('service_role','public.saas_activate_intent_v1(text,timestamptz)','execute') as service_activate_must_be_true;
select count(*) as intent_aberta from public.saas_checkout_intents where status in ('created','sent','processing');
select count(*) as assinatura_ativa from public.saas_subscriptions where status = 'active';
-- Marcador final: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M25_POST_APPLY_OK::saas_billing' as marcador
 where to_regclass('public.saas_plans') is not null
   and to_regclass('public.saas_checkout_intents') is not null
   and to_regprocedure('public.saas_create_checkout_intent_v1(uuid,text,jsonb)') is not null
   and (select count(*) from public.saas_plans where code = 'padrao' and active and price_cents = 19900) = 1
   and (select count(*) from public.saas_plan_capabilities pc
        join public.saas_plans p on p.id = pc.plan_id where p.code = 'padrao') = 13
   and not has_table_privilege('anon','public.saas_subscriptions','select')
   and not has_function_privilege('anon','public.saas_activate_intent_v1(text,timestamptz)','execute')
   and (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname in
        ('saas_plans','saas_plan_capabilities','saas_checkout_intents','saas_subscriptions','saas_billing_events')
        and c.relrowsecurity) = 5;
