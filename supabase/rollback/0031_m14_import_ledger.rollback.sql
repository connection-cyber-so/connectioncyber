begin;
drop function if exists public.erp_finalize_import_batch(uuid,uuid,text);
drop function if exists public.erp_record_import_item(uuid,uuid,text,text,text,bigint);
drop function if exists public.erp_open_import_batch(uuid,uuid,text,integer,text,integer,bigint);
drop function if exists public.erp_open_import_job(uuid,uuid,text,bigint,bigint);
drop function if exists public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb);
drop table if exists public.erp_import_reconciliations,public.erp_import_rejections,public.erp_import_items,public.erp_import_batches,public.erp_import_jobs,public.erp_import_mappings,public.erp_import_manifests cascade;
delete from public.erp_permissions where key in('import.read','import.execute','import.audit');
commit;
