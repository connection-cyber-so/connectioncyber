do $$begin
if current_setting('server_version_num')::integer<150000 then raise exception 'PostgreSQL 15+ required';end if;
if to_regprocedure('erp_security.has_permission(uuid,text)')is null or to_regclass('public.erp_fiscal_documents')is null then raise exception 'M04/M13 missing';end if;
if to_regclass('public.erp_import_manifests')is not null or to_regprocedure('public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)')is not null then raise exception 'M14 objects already exist without history 0031';end if;
if exists(select 1 from public.erp_permissions where key in('import.read','import.execute','import.audit')and category<>'Importacao')then raise exception 'M14 permission collision';end if;
end$$;
select now()checked_at,'M14_0031_PREFLIGHT_OK'result;
