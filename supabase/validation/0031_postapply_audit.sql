do $$
declare table_count integer;rls_count integer;function_count integer;security_definer_count integer;data_count bigint;
begin
 select count(*),count(*)filter(where c.relrowsecurity)into table_count,rls_count from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relname like'erp_import_%'and c.relkind='r';
 if table_count<>7 or rls_count<>7 then raise exception 'M14 table/RLS mismatch: %/%',table_count,rls_count;end if;
 select count(*),count(*)filter(where p.prosecdef)into function_count,security_definer_count from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname like'erp_%import%';
 if function_count<>5 or security_definer_count<>5 then raise exception 'M14 RPC mismatch: %/%',function_count,security_definer_count;end if;
 if (select count(*)from public.erp_permissions where key in('import.read','import.audit'))<>2 or exists(select 1 from public.erp_permissions where key='import.execute')then raise exception 'M14 permission mismatch';end if;
 select (select count(*)from public.erp_import_manifests)+(select count(*)from public.erp_import_jobs)+(select count(*)from public.erp_import_batches)+(select count(*)from public.erp_import_items)+(select count(*)from public.erp_import_reconciliations)into data_count;
 if data_count<>0 then raise exception 'M14 unexpected data: %',data_count;end if;
end$$;
select 'M14_0031_POSTAPPLY_AUDIT_OK' result;
