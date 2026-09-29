begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(38);

select ok(to_regclass(format('public.%I',table_name))is not null,format('tabela %s existe',table_name))
 from unnest(array['saas_plans','saas_plan_capabilities','saas_checkout_intents','saas_subscriptions','saas_billing_events']) names(table_name);
select ok(c.relrowsecurity,format('RLS ativo em %s',c.relname))
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public'and c.relname=any(array['saas_plans','saas_plan_capabilities','saas_checkout_intents','saas_subscriptions','saas_billing_events']) order by c.relname;
select ok((select count(*) from pg_policies where schemaname='public'
 and tablename in('saas_plans','saas_plan_capabilities'))=2
 and not exists(select 1 from pg_policies where schemaname='public'
 and tablename in('saas_plans','saas_plan_capabilities')and cmd<>'SELECT'),
 'somente 2 policies publicas, ambas de select');
select ok((select count(*) from public.saas_plans where code='padrao'and price_cents=19900
 and active and currency='BRL'and trial_days=0)=1,'plano padrao seedado com placeholder 19900');
select ok((select count(*) from public.saas_plan_capabilities pc
 join public.saas_plans p on p.id=pc.plan_id where p.code='padrao')=13,'13 capabilities no plano padrao');
select ok(has_table_privilege('anon','public.saas_plans','SELECT')
 and has_table_privilege('anon','public.saas_plan_capabilities','SELECT'),'anon le o catalogo de planos');
select ok(not has_table_privilege('anon','public.saas_plans','INSERT')
 and not has_table_privilege('anon','public.saas_plans','UPDATE')
 and not has_table_privilege('anon','public.saas_plans','DELETE'),'anon nao escreve planos');
select ok(not has_table_privilege('anon',format('public.%I',table_name),'SELECT')
 and not has_table_privilege('authenticated',format('public.%I',table_name),'SELECT'),
 format('anon e authenticated nao leem %s',table_name))
 from unnest(array['saas_checkout_intents','saas_subscriptions','saas_billing_events']) names(table_name);
select ok((select count(*) from unnest(array['saas_plans','saas_plan_capabilities','saas_checkout_intents','saas_subscriptions','saas_billing_events'])t(name)
 where has_table_privilege('service_role',format('public.%I',t.name),'SELECT')
   and has_table_privilege('service_role',format('public.%I',t.name),'INSERT')
   and has_table_privilege('service_role',format('public.%I',t.name),'UPDATE')
   and has_table_privilege('service_role',format('public.%I',t.name),'DELETE'))=5,'service_role com DML nas 5 tabelas');
select ok((select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public'and p.proname like 'saas\_%')=6,'6 funcoes saas_* criadas');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public'and p.proname like 'saas\_%'and has_function_privilege('anon',p.oid,'execute')),
 'anon sem execute em nenhuma funcao saas');
select ok((select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public'and p.proname like 'saas\_%'and has_function_privilege('service_role',p.oid,'execute'))=6,
 'service_role com execute nas 6');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public'and p.proname like 'saas\_%'and has_function_privilege('authenticated',p.oid,'execute')),
 'authenticated sem execute em nenhuma funcao saas');
select ok((select prosecdef from pg_proc where oid='public.saas_create_checkout_intent_v1(uuid,text,jsonb)'::regprocedure)
 and pg_get_functiondef('public.saas_create_checkout_intent_v1(uuid,text,jsonb)'::regprocedure)like '%auth.role()%'
 and pg_get_functiondef('public.saas_create_checkout_intent_v1(uuid,text,jsonb)'::regprocedure)like '%invalid tenant payload%',
 'create_intent: definer, service_role only e allow-list fail-closed');
select ok(pg_get_functiondef('public.saas_create_checkout_intent_v1(uuid,text,jsonb)'::regprocedure)like '%extensions.digest%',
 'create_intent grava request_hash SHA-256 do payload');
select ok((select prosecdef from pg_proc where oid='public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)
 and pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%erp_prepare_pilot_provisioning_v1%'
 and pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%erp_record_pilot_auth_identity_v1%'
 and pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%erp_finalize_pilot_identity_v1%',
 'activate encadeia prepare -> record -> finalize (0034)');
select ok(pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%provisioned%'
 and pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%replayed%','activate idempotente');
select ok(pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%owner.%'
 and pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%protected:SAAS_OWNER%',
 'activate monta ownerSubjectKey e ownerEmailRef do 0034');
select ok(pg_get_functiondef('public.saas_activate_intent_v1(text,timestamptz)'::regprocedure)like '%when others%',
 'activate marca intent failed na excecao (trilha de erro)');
select ok((select prosecdef from pg_proc where oid='public.saas_set_subscription_status_v1(text,text,text)'::regprocedure)
 and pg_get_functiondef('public.saas_set_subscription_status_v1(text,text,text)'::regprocedure)like '%erp_set_tenant_capability%',
 'set_status: definer e suspende/reativa via broker de capabilities');
select ok((select prosecdef from pg_proc where oid='public.saas_record_billing_event_v1(text,text,text,text,text,jsonb)'::regprocedure)
 and pg_get_functiondef('public.saas_record_billing_event_v1(text,text,text,text,text,jsonb)'::regprocedure)like '%do nothing%',
 'record event: definer e idempotente por (topic,external_id)');
select ok((select prosecdef from pg_proc where oid='public.saas_bind_preapproval_v1(uuid,text,text)'::regprocedure)
 and pg_get_functiondef('public.saas_bind_preapproval_v1(uuid,text,text)'::regprocedure)like '%status = ''sent''%',
 'bind: definer e transiciona created -> sent');
select ok((select count(*) from pg_constraint c join pg_class t on t.oid=c.conrelid
 join pg_namespace n on n.oid=t.relnamespace where n.nspname='public'and t.relname='saas_checkout_intents'
 and pg_get_constraintdef(c.oid)like '%created%'and pg_get_constraintdef(c.oid)like '%sent%'
 and pg_get_constraintdef(c.oid)like '%provisioned%')>=1,'constraint de status da intent existe');
select ok((select count(*) from pg_constraint c join pg_class t on t.oid=c.conrelid
 join pg_namespace n on n.oid=t.relnamespace where n.nspname='public'and t.relname='saas_subscriptions'
 and pg_get_constraintdef(c.oid)like '%cancelled_at IS NOT NULL%')>=1,'constraint cancelled exige cancelled_at');
select ok((select count(*) from pg_indexes where schemaname='public'
 and indexname='saas_checkout_intents_open_per_user_plan')=1,'indice unico de intent aberta por usuario+plano');
select ok((select count(*) from pg_constraint c join pg_class t on t.oid=c.conrelid
 join pg_namespace n on n.oid=t.relnamespace where n.nspname='public'and t.relname='saas_checkout_intents'
 and c.contype='u'and pg_get_constraintdef(c.oid)like '%mp_preapproval_id%')>=1,'unidade de mp_preapproval_id na intent');
select ok((select count(*) from information_schema.table_constraints tc
 join information_schema.constraint_column_usage ccu
   on tc.constraint_name=ccu.constraint_name and tc.table_schema=ccu.constraint_schema
 where tc.table_schema='public'and tc.table_name='saas_plan_capabilities'
 and tc.constraint_type='FOREIGN KEY'and ccu.table_name='erp_capability_catalog')>=1,
 'FK de capability para o catalogo canonico');
select ok((select count(*) from information_schema.table_constraints tc
 join information_schema.constraint_column_usage ccu
   on tc.constraint_name=ccu.constraint_name and tc.table_schema=ccu.constraint_schema
 where tc.table_schema='public'and tc.table_name='saas_subscriptions'
 and tc.constraint_type='FOREIGN KEY'and ccu.table_name='saas_checkout_intents')>=1,
 'FK de subscription para a intent');

select * from finish();
rollback;
