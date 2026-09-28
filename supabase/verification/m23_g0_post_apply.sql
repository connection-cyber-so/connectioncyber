-- M23-G0 post-apply verification (read-only): run after applying 0044.
select tablename,rowsecurity from pg_tables
 where schemaname='public' and tablename like 'academy_%' order by tablename;
select tablename,policyname,cmd from pg_policies
 where schemaname='public' and tablename like 'academy_%' order by tablename,cmd;
select has_table_privilege('authenticated','public.academy_courses','insert') as must_be_false,
       has_table_privilege('anon','public.academy_courses','select') as must_be_false,
       has_function_privilege('anon','public.academy_command(uuid,text,uuid,jsonb)','execute') as must_be_false;
select has_table_privilege('anon','public.courses','select') as must_be_true,
       has_table_privilege('anon','public.products','select') as must_be_true,
       has_table_privilege('anon','public.cms_content','select') as must_be_true;
select key,risk_level,active from public.erp_capability_catalog where key='academy.courses';
select key,active from public.erp_permissions where key like 'academy.%' order by key;
select to_regprocedure('public.academy_command(uuid,text,uuid,jsonb)') as command,
       to_regprocedure('public.academy_context(uuid)') as context,
       to_regprocedure('erp_security.academy_access(uuid)') as access,
       to_regprocedure('erp_security.academy_manage(uuid)') as manage;
