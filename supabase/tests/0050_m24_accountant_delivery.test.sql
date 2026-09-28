begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(36);
select ok(to_regclass(format('public.%I',table_name))is not null,format('tabela %s existe',table_name))
 from unnest(array['erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events']) names(table_name);
select ok(c.relrowsecurity,format('RLS ativo em %s',c.relname))
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public'and c.relname=any(array['erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events']) order by c.relname;
select ok(not has_table_privilege('anon',format('public.%I',table_name),'SELECT'),format('anon nao le %s',table_name))
 from unnest(array['erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events']) names(table_name);
select ok(has_table_privilege('authenticated',format('public.%I',table_name),'SELECT'),format('authenticated le %s sob RLS',table_name))
 from unnest(array['erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events']) names(table_name);
select ok(not has_table_privilege('authenticated',format('public.%I',table_name),'INSERT')
 and not has_table_privilege('authenticated',format('public.%I',table_name),'UPDATE')
 and not has_table_privilege('authenticated',format('public.%I',table_name),'DELETE'),format('authenticated nao escreve %s direto',table_name))
 from unnest(array['erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events']) names(table_name);
select ok((select count(*) from pg_policies where schemaname='public'
 and tablename in('erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events'))=3
 and not exists(select 1 from pg_policies where schemaname='public'
 and tablename in('erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events')
 and cmd<>'SELECT'),'somente 3 policies de select (escrita exclusiva via RPC)');
select ok(exists(select 1 from public.roles where nome='contador'),'papel contador existe');
select ok((select prosecdef from pg_proc where oid='public.is_accountant()'::regprocedure)
 and not exists(select 1 from pg_proc p,unnest(p.proconfig)cfg where p.oid='public.is_accountant()'::regprocedure and cfg like 'search_path=%public%')
 and not has_function_privilege('anon','public.is_accountant()','execute')
 and has_function_privilege('authenticated','public.is_accountant()','execute'),'is_accountant definer, search_path vazio, sem anon');
select ok(not has_function_privilege('anon','public.erp_publish_accountant_package(uuid,date,jsonb,text)','EXECUTE')
 and has_function_privilege('authenticated','public.erp_publish_accountant_package(uuid,date,jsonb,text)','EXECUTE'),'publish: sem anon, com authenticated');
select ok((select prosecdef from pg_proc where oid='public.erp_publish_accountant_package(uuid,date,jsonb,text)'::regprocedure)
 and pg_get_functiondef('public.erp_publish_accountant_package(uuid,date,jsonb,text)'::regprocedure)like '%fiscal.deliver%'
 and pg_get_functiondef('public.erp_publish_accountant_package(uuid,date,jsonb,text)'::regprocedure)like '%left(v_path,length(v_prefix))%'
 and pg_get_functiondef('public.erp_publish_accountant_package(uuid,date,jsonb,text)'::regprocedure)like '%order by l%',
 'publish: definer, exige fiscal.deliver, trava prefixo do tenant e manifesto canonico ordenado');
select ok(pg_get_functiondef('public.erp_publish_accountant_package(uuid,date,jsonb,text)'::regprocedure)like '%extensions.digest%',
 'manifesto hashado no servidor com SHA-256');
select ok((select prosecdef from pg_proc where oid='public.erp_list_accountant_packages(uuid,integer)'::regprocedure)
 and pg_get_functiondef('public.erp_list_accountant_packages(uuid,integer)'::regprocedure)like '%logs_access%'
 and pg_get_functiondef('public.erp_list_accountant_packages(uuid,integer)'::regprocedure)like '%is_accountant()%',
 'list: definer, exige papel contador/staff e grava log quebra-vidro');
select ok(not has_function_privilege('anon','public.erp_list_accountant_packages(uuid,integer)','EXECUTE'),'list sem anon');
select ok((select prosecdef from pg_proc where oid='public.erp_ack_accountant_package(uuid,uuid,text,text)'::regprocedure)
 and pg_get_functiondef('public.erp_ack_accountant_package(uuid,uuid,text,text)'::regprocedure)like '%is_accountant()%'
 and pg_get_functiondef('public.erp_ack_accountant_package(uuid,uuid,text,text)'::regprocedure)like '%logs_access%',
 'ack: definer, exige contador/staff e audita');
select ok((select prosecdef from pg_proc where oid='public.erp_void_accountant_package(uuid,uuid,text,text)'::regprocedure)
 and pg_get_functiondef('public.erp_void_accountant_package(uuid,uuid,text,text)'::regprocedure)like '%fiscal.deliver%',
 'void: definer e exige fiscal.deliver');
select ok((select prosecdef from pg_proc where oid='public.erp_log_accountant_download(uuid,uuid,integer)'::regprocedure)
 and pg_get_functiondef('public.erp_log_accountant_download(uuid,uuid,integer)'::regprocedure)like '%logs_access%',
 'download log: definer e audita');
select ok(not has_function_privilege('anon','public.erp_ack_accountant_package(uuid,uuid,text,text)','EXECUTE')
 and not has_function_privilege('anon','public.erp_void_accountant_package(uuid,uuid,text,text)','EXECUTE')
 and not has_function_privilege('anon','public.erp_log_accountant_download(uuid,uuid,integer)','EXECUTE'),'demais RPCs sem anon');
select ok(exists(select 1 from pg_constraint where conname='erp_accountant_packages_tenant_id_competencia_key'),'um pacote por competencia');
select ok(exists(select 1 from pg_constraint where conname='erp_accountant_packages_tenant_id_idempotency_key_key'),'pacote idempotente');
select ok(exists(select 1 from pg_constraint where conname='erp_accountant_delivery_events_tenant_id_idempotency_key_key'),'evento idempotente');
select ok(exists(select 1 from pg_constraint where conname='erp_accountant_package_files_tenant_id_package_id_storage_p_key'),'arquivo unico por caminho no pacote');
select ok(exists(select 1 from pg_constraint where conname='erp_accountant_package_files_tenant_id_package_id_fkey'),'arquivo pertence ao pacote');
select ok((select count(*) from public.erp_permissions where key='fiscal.deliver')=1,'permissao fiscal.deliver existe');
select ok(exists(select 1 from storage.buckets where id='fiscal-deliveries' and public=false and file_size_limit=10485760),'bucket fiscal-deliveries privado 10MB');
select ok((select count(*) from pg_policies where tablename='objects' and policyname like 'fd_storage_%')=5,'5 storage policies do bucket fiscal');
select ok((select count(*) from pg_indexes where indexname='idx_accountant_packages_competencia')=1,'indice de competencia desc existe');
select * from finish();
rollback;
