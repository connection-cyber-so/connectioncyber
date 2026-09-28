begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(12);
select ok((select pg_get_functiondef('public.academy_sync_links(uuid)'::regprocedure) like '%academy_capability(t.id)%'),
  'sincronia exige a capacidade da empresa no conjunto desejado');
select ok((select pg_get_functiondef('public.academy_sync_links(uuid)'::regprocedure) like '%tenant_modules%'
  and pg_get_functiondef('public.academy_sync_links(uuid)'::regprocedure) like '%alvo_vertical%'),
  'corte de capacidade nao apaga a regra de alvo (sistema e vertical)');
select ok((select prosecdef from pg_proc where oid='public.academy_sync_links(uuid)'::regprocedure)
  and (select exists(select 1 from unnest(proconfig) cfg where cfg like 'search_path=%' and cfg not like '%public%')
       from pg_proc where oid='public.academy_sync_links(uuid)'::regprocedure)
  and not has_function_privilege('anon','public.academy_sync_links(uuid)','execute'),
  'academy_sync_links continua definer com search_path vazio e sem execucao anonima');
select ok((select count(*) from pg_proc where proname='academy_sync_capability_trg')=1,
  'funcao do gatilho de capacidade existe');
select ok((select pg_get_functiondef(p.oid) like '%academy.courses%'
  and pg_get_functiondef(p.oid) like '%tg_op%'
  and pg_get_functiondef(p.oid) like '%academy_sync_links()%'
        from pg_proc p where p.proname='academy_sync_capability_trg'),
  'gatilho filtra a chave academy.courses e recalcula o catalogo');
select ok((select count(*) from pg_trigger where not tgisinternal
  and tgname in ('trg_academy_capabilities_sync','trg_academy_capability_exceptions_sync'))=2,
  '2 gatilhos de capacidade existem');
select ok((select count(*) from pg_trigger where not tgisinternal
  and tgname in ('trg_academy_capabilities_sync','trg_academy_capability_exceptions_sync')
  and tgrelid in ('public.erp_tenant_capabilities'::regclass,'public.erp_tenant_capability_exceptions'::regclass))=2,
  'gatilhos ficam nas duas tabelas de capacidade');
select ok((select count(*) from pg_trigger where not tgisinternal
  and tgname in ('trg_academy_capabilities_sync','trg_academy_capability_exceptions_sync')
  and pg_get_triggerdef(oid) like '%AFTER%'
  and pg_get_triggerdef(oid) like '%INSERT%'
  and pg_get_triggerdef(oid) like '%UPDATE%'
  and pg_get_triggerdef(oid) like '%DELETE%'
  and pg_get_triggerdef(oid) like '%FOR EACH ROW%')=2,
  'gatilhos sao AFTER I+U+D por linha');
select ok(not has_function_privilege('anon','public.academy_sync_capability_trg()','execute')
  and has_function_privilege('authenticated','public.academy_sync_capability_trg()','execute'),
  'grants da funcao do gatilho: sem anon, com authenticated');
select ok((select count(*) from pg_trigger where not tgisinternal
  and tgname in ('trg_academy_courses_sync','trg_tenant_modules_academy_sync',
                 'trg_tenants_academy_sync_insert','trg_tenants_academy_sync_vertical'))=4,
  'os 4 gatilhos da 0048 permanecem');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and table_name='academy_tenant_courses'
  and privilege_type in ('INSERT','UPDATE','DELETE'))=0
  and (select c.relrowsecurity from pg_class c where c.oid=to_regclass('public.academy_tenant_courses')),
  'vinculo continua com RLS e sem DML para cliente');
select ok((select count(*) from pg_policies where tablename like 'academy\_%'
  and cmd in ('INSERT','UPDATE','DELETE'))=0,'nenhuma policy de escrita nova');
select * from finish();
rollback;
