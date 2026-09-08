begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(8);

select ok(to_regprocedure('public.erp_prepare_pilot_establishment_v1(text,jsonb)') is not null,'erp_prepare_pilot_establishment_v1 exists');
select ok(p.prosecdef,'erp_prepare_pilot_establishment_v1 is security definer') from pg_proc p where p.oid = 'public.erp_prepare_pilot_establishment_v1(text,jsonb)'::regprocedure;
select ok(exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%' and c not like '%public%'),'erp_prepare_pilot_establishment_v1 has empty search path') from pg_proc p where p.oid = 'public.erp_prepare_pilot_establishment_v1(text,jsonb)'::regprocedure;
select ok(not has_function_privilege('anon','public.erp_prepare_pilot_establishment_v1(text,jsonb)','EXECUTE'),'anon cannot execute erp_prepare_pilot_establishment_v1');
select ok(not has_function_privilege('authenticated','public.erp_prepare_pilot_establishment_v1(text,jsonb)','EXECUTE'),'authenticated cannot execute erp_prepare_pilot_establishment_v1');
select ok(has_function_privilege('service_role','public.erp_prepare_pilot_establishment_v1(text,jsonb)','EXECUTE'),'service role executes erp_prepare_pilot_establishment_v1');
select ok(pg_get_functiondef('public.erp_prepare_pilot_establishment_v1(text,jsonb)'::regprocedure) like '%pg_advisory_xact_lock%','establishment prepare serializes idempotency');
select ok(pg_get_functiondef('public.erp_prepare_pilot_establishment_v1(text,jsonb)'::regprocedure) like '%erp_auth_invitation_outbox%','establishment prepare enqueues invitation atomically');

select * from finish();
rollback;
