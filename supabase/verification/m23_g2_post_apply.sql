-- M23-G2 post-apply verification (read-only): run after applying 0048.
select column_name,data_type from information_schema.columns
 where table_schema='public' and table_name='academy_courses'
 and column_name in ('escopo','alvo_sistema','alvo_vertical','publico') order by column_name;
select conname,pg_get_constraintdef(oid) as definicao from pg_constraint
 where conrelid in (to_regclass('public.academy_enrollments'),to_regclass('public.academy_progress'),
                    to_regclass('public.academy_events'),to_regclass('public.academy_modules'))
 and contype='f' order by conrelid::regclass::text,conname;
select tablename,rowsecurity from pg_tables
 where schemaname='public' and tablename like 'academy_%' order by tablename;
select tablename,policyname,cmd from pg_policies
 where schemaname='public' and tablename like 'academy_%' order by tablename,cmd;
select tgname from pg_trigger where not tgisinternal and tgname like '%academy_sync%' order by tgname;
select has_table_privilege('authenticated','public.academy_tenant_courses','insert') as must_be_false,
       has_table_privilege('anon','public.academy_tenant_courses','select') as must_be_false,
       has_function_privilege('anon','public.academy_sync_links(uuid)','execute') as must_be_false;
select has_table_privilege('anon','public.courses','select') as must_be_true,
       has_table_privilege('anon','public.products','select') as must_be_true,
       has_table_privilege('anon','public.cms_content','select') as must_be_true;
select id,titulo,escopo,publico,alvo_sistema,alvo_vertical,status from public.academy_courses order by escopo,titulo;
select ten.nome as tenant,t.course_id,t.origem,t.ativo from public.academy_tenant_courses t
 join public.tenants ten on ten.id=t.tenant_id order by ten.nome,t.course_id;
select to_regprocedure('public.academy_sync_links(uuid)') as sync_links,
       to_regprocedure('public.academy_validate_targets(boolean,text,text)') as validate_targets,
       to_regprocedure('public.academy_command(uuid,text,uuid,jsonb)') as command,
       to_regprocedure('public.academy_context(uuid)') as context;
-- Marcador final: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M23_G2_POST_APPLY_OK::academy_tenant_courses' as marcador
 where to_regclass('public.academy_tenant_courses') is not null
   and exists(select 1 from information_schema.columns
               where table_schema='public' and table_name='academy_courses'
                 and column_name='escopo');
