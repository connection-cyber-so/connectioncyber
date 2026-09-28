begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(24);
select ok(to_regclass('public.academy_tenant_courses') is not null,'academy_tenant_courses existe');
select ok((select c.relrowsecurity from pg_class c where c.oid=to_regclass('public.academy_tenant_courses')),'RLS habilitado em academy_tenant_courses');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and table_name='academy_tenant_courses'
  and privilege_type in ('INSERT','UPDATE','DELETE'))=0,'authenticated sem DML em academy_tenant_courses');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='anon' and table_schema='public' and table_name='academy_tenant_courses')=0,'anon sem privilegio em academy_tenant_courses');
select ok((select count(*) from information_schema.columns
  where table_schema='public' and table_name='academy_courses'
  and column_name in ('escopo','alvo_sistema','alvo_vertical','publico'))=4,'4 colunas novas em academy_courses');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_courses')
  and conname in ('academy_courses_escopo_chk','academy_courses_scope_target_chk'))=2,'constraints de escopo existem');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_courses')
  and conname in ('academy_courses_alvo_sistema_chk','academy_courses_alvo_vertical_chk'))=2,'constraints de alvo existem');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_enrollments') and contype='f'
  and conname='academy_enrollments_course_fkey')=1,'FK de enrollments e simples (course_id)');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_enrollments') and contype='f'
  and conname like '%tenant_id%course_id%')=0,'FK composta antiga de enrollments removida');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_progress') and contype='f'
  and conname in ('academy_progress_course_fkey','academy_progress_module_fkey'))=2,'FKs de progress sao simples');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_events') and contype='f'
  and conname='academy_events_course_fkey')=1,'FK de events e simples (course_id)');
select ok((select count(*) from pg_constraint
  where conrelid=to_regclass('public.academy_modules') and contype='f'
  and conname like '%tenant_id%course_id%')=1,'FK composta de modules mantida (dono)');
select ok((select count(*) from pg_policies
  where tablename='academy_courses' and cmd='SELECT'
  and qual like '%academy_tenant_courses%')=1,'policy de courses le por vinculo');
select ok((select count(*) from pg_policies
  where tablename='academy_modules' and cmd='SELECT'
  and qual like '%academy_tenant_courses%')=1,'policy de modules le por vinculo');
select ok((select count(*) from pg_policies
  where tablename='academy_tenant_courses' and cmd='SELECT'
  and qual like '%academy_access%')=1,'policy do vinculo exige academy_access');
select ok((select count(*) from pg_policies
  where tablename like 'academy\_%' and cmd in ('INSERT','UPDATE','DELETE'))=0,'nenhuma policy de escrita em tabelas academy');
select ok((select pg_get_functiondef('public.academy_command(uuid,text,uuid,jsonb)'::regprocedure) like '%link_course%'
  and pg_get_functiondef('public.academy_command(uuid,text,uuid,jsonb)'::regprocedure) like '%set_course_targets%'
  and pg_get_functiondef('public.academy_command(uuid,text,uuid,jsonb)'::regprocedure) like '%academy_tenant_courses%'),
  'command tem acoes novas e valida vinculo');
select ok((select prosecdef from pg_proc where oid='public.academy_command(uuid,text,uuid,jsonb)'::regprocedure)
  and (select exists(select 1 from unnest(proconfig) cfg where cfg like 'search_path=%' and cfg not like '%public%')
       from pg_proc where oid='public.academy_command(uuid,text,uuid,jsonb)'::regprocedure),
  'command continua security definer com search_path vazio');
select ok((select pg_get_functiondef('public.academy_context(uuid)'::regprocedure) like '%is_platform_staff%'),
  'academy_context expoe staff');
select ok((select prosecdef from pg_proc where oid='public.academy_sync_links(uuid)'::regprocedure)
  and (select exists(select 1 from unnest(proconfig) cfg where cfg like 'search_path=%' and cfg not like '%public%')
       from pg_proc where oid='public.academy_sync_links(uuid)'::regprocedure)
  and not has_function_privilege('anon','public.academy_sync_links(uuid)','execute'),
  'academy_sync_links e definer sem execucao anonima');
select ok((select count(*) from pg_trigger where not tgisinternal
  and tgname in ('trg_academy_courses_sync','trg_tenant_modules_academy_sync',
                 'trg_tenants_academy_sync_insert','trg_tenants_academy_sync_vertical'))=4,
  '4 gatilhos de sincronia C+ existem');
select ok(not has_function_privilege('anon','public.academy_validate_targets(boolean,text,text)','execute')
  and has_function_privilege('authenticated','public.academy_validate_targets(boolean,text,text)','execute'),
  'validate_targets com grants corretos');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public'
  and privilege_type in ('INSERT','UPDATE','DELETE') and table_name like 'academy\_%')=0,
  'authenticated sem DML nas tabelas academy');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='anon' and table_schema='public' and table_name like 'academy\_%')=0,
  'anon sem privilegio nas tabelas academy');
select * from finish();
rollback;
