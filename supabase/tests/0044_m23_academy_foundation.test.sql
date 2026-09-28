begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(18);
select ok(to_regprocedure('public.academy_command(uuid,text,uuid,jsonb)') is not null,'academy_command existe');
select ok((select prosecdef from pg_proc where oid='public.academy_command(uuid,text,uuid,jsonb)'::regprocedure),'academy_command e security definer');
select ok((select exists(select 1 from unnest(proconfig) cfg where cfg like 'search_path=%' and cfg not like '%public%') from pg_proc where oid='public.academy_command(uuid,text,uuid,jsonb)'::regprocedure),'academy_command com search_path vazio');
select ok(not has_function_privilege('anon','public.academy_command(uuid,text,uuid,jsonb)','execute'),'anon nao executa academy_command');
select ok(has_function_privilege('authenticated','public.academy_command(uuid,text,uuid,jsonb)','execute'),'authenticated executa academy_command');
select ok(has_function_privilege('service_role','public.academy_command(uuid,text,uuid,jsonb)','execute'),'service_role executa academy_command');
select ok((select prosecdef from pg_proc where oid='erp_security.academy_access(uuid)'::regprocedure),'academy_access e security definer');
select ok(not has_function_privilege('anon','erp_security.academy_access(uuid)','execute'),'anon nao executa academy_access');
select ok(has_function_privilege('authenticated','erp_security.academy_access(uuid)','execute'),'authenticated executa academy_access');
select ok((select pg_get_functiondef('erp_security.academy_manage(uuid)'::regprocedure) like '%has_permission_at_aal%'),'academy_manage exige nivel de garantia');
select ok((select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r' and c.relrowsecurity
  and c.relname in ('academy_courses','academy_modules','academy_enrollments','academy_progress','academy_events'))=5,'RLS habilitado nas 5 tabelas academy');
select ok((select count(distinct table_name) from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public' and privilege_type='SELECT'
  and table_name in ('academy_courses','academy_modules','academy_enrollments','academy_progress','academy_events'))=5,'authenticated consulta as 5 tabelas academy');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='authenticated' and table_schema='public'
  and privilege_type in ('INSERT','UPDATE','DELETE') and table_name like 'academy\_%')=0,'authenticated sem DML nas tabelas academy');
select ok((select count(*) from information_schema.role_table_grants
  where grantee='anon' and table_schema='public' and table_name like 'academy\_%')=0,'anon sem privilegio nas tabelas academy');
select ok((select count(*) from public.erp_capability_catalog where key='academy.courses' and active)=1,'capacidade academy.courses catalogada');
select ok((select count(*) from public.erp_permissions where key in ('academy.read','academy.manage') and active)=2,'permissoes academy.read e academy.manage cadastradas');
select ok(has_table_privilege('anon','public.courses','select') and has_table_privilege('anon','public.products','select') and has_table_privilege('anon','public.cms_content','select'),'anon le o catalogo publico (correcao do 42501)');
select ok(to_regclass('public.academy_modules_course_order') is not null,'indice unico de ordem de modulo existe');
select * from finish();
rollback;
