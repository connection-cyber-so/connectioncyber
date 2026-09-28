-- M24 post-apply verification (read-only): run after applying 0050.
select to_regclass('public.erp_accountant_packages') as pacotes,
       to_regclass('public.erp_accountant_package_files') as arquivos,
       to_regclass('public.erp_accountant_delivery_events') as eventos;
select to_regprocedure('public.erp_publish_accountant_package(uuid,date,jsonb,text)') as rpc_publicar,
       to_regprocedure('public.erp_list_accountant_packages(uuid,integer)') as rpc_listar,
       to_regprocedure('public.erp_ack_accountant_package(uuid,uuid,text,text)') as rpc_recibo,
       to_regprocedure('public.erp_void_accountant_package(uuid,uuid,text,text)') as rpc_anular,
       to_regprocedure('public.erp_log_accountant_download(uuid,uuid,integer)') as rpc_log,
       to_regprocedure('public.is_accountant()') as fn_contador;
select nome as papel_contador from public.roles where nome = 'contador';
select count(*) as permissao_fiscal_deliver from public.erp_permissions where key = 'fiscal.deliver';
select id, name, public from storage.buckets where id = 'fiscal-deliveries';
select count(*) as storage_policies_fd from pg_policies
 where schemaname = 'storage' and tablename = 'objects' and policyname like 'fd_storage_%';
select c.relname, c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname in
 ('erp_accountant_packages','erp_accountant_package_files','erp_accountant_delivery_events')
 order by c.relname;
select has_table_privilege('anon','public.erp_accountant_packages','select') as anon_packages_select_must_be_false,
       has_function_privilege('anon','public.erp_publish_accountant_package(uuid,date,jsonb,text)','execute') as anon_publish_must_be_false,
       has_function_privilege('authenticated','public.erp_list_accountant_packages(uuid,integer)','execute') as auth_list_must_be_true;
select count(*) as pacotes_reais from public.erp_accountant_packages;
select count(*) as eventos_reais from public.erp_accountant_delivery_events;
-- Marcador final: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M24_POST_APPLY_OK::accountant_delivery' as marcador
 where to_regclass('public.erp_accountant_packages') is not null
   and exists(select 1 from public.roles where nome = 'contador')
   and exists(select 1 from public.erp_permissions where key = 'fiscal.deliver')
   and exists(select 1 from storage.buckets where id = 'fiscal-deliveries')
   and (select count(*) from pg_policies where schemaname = 'storage'
        and tablename = 'objects' and policyname like 'fd_storage_%') = 5
   and not has_table_privilege('anon','public.erp_accountant_packages','select');
