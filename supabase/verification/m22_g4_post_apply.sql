select tablename,rowsecurity from pg_tables where schemaname='public' and tablename like 'kb_%' order by tablename;
select tablename,policyname,cmd from pg_policies where schemaname='public' and tablename like 'kb_%';
select id,public,file_size_limit from storage.buckets where id='knowledge-base';
select has_table_privilege('authenticated','public.kb_items','insert') as must_be_false,
 has_function_privilege('anon','public.kb_command(uuid,text,uuid,integer,jsonb)','execute') as must_be_false;
