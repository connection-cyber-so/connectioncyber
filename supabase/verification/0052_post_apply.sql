-- M14 0052 post-apply verification (read-only): run after applying 0052.
select to_regclass('public.erp_import_manifests') as manifestos,
       to_regprocedure('public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)') as rpc_manifesto,
       to_regprocedure('public.erp_open_import_job(uuid,uuid,text,bigint,bigint)') as rpc_job,
       to_regprocedure('public.erp_finalize_import_batch(uuid,uuid,text)') as rpc_finalize;
select pg_get_constraintdef(oid) as check_source_type
  from pg_constraint
 where conrelid = 'public.erp_import_manifests'::regclass
   and conname = 'erp_import_manifests_source_type_check';
select count(*) as rpc_aceita_nfe_xml
  from pg_proc where proname = 'erp_register_import_manifest'
 and pg_get_functiondef(oid) like '%nfe_xml%';
select count(*) as tabelas_ledger from information_schema.tables
 where table_schema = 'public' and table_name like 'erp_import_%';
select count(*) as policies_ledger from pg_policies
 where schemaname = 'public' and tablename like 'erp_import_%';
select has_function_privilege('service_role','public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)','execute') as service_exec_must_be_true,
       has_function_privilege('anon','public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)','execute') as anon_exec_must_be_false;
select c.relname, c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname = 'public' and c.relname like 'erp_import_%' and c.relkind = 'r' order by c.relname;
select count(*) as historico_ate_0052 from supabase_migrations.schema_migrations
 where version = '0052';
-- Marcador final: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M14_0052_POST_APPLY_OK::nfe_xml_source' as marcador
 where exists(select 1 from pg_proc where proname = 'erp_register_import_manifest'
              and pg_get_functiondef(oid) like '%nfe_xml%')
   and exists(select 1 from pg_constraint where conrelid = 'public.erp_import_manifests'::regclass
              and conname = 'erp_import_manifests_source_type_check'
              and pg_get_constraintdef(oid) like '%nfe_xml%')
   and exists(select 1 from supabase_migrations.schema_migrations where version = '0052');
