do $$begin
if to_regclass('public.erp_fiscal_documents')is not null then raise exception 'M13_0030_TABLE_RESIDUE';end if;
if to_regprocedure('public.erp_reserve_fiscal_number(uuid,uuid,text,text,integer,text)')is not null then raise exception 'M13_0030_FUNCTION_RESIDUE';end if;
if exists(select 1 from pg_constraint where conname='erp_sales_tenant_establishment_id_unique')then raise exception 'M13_0030_CONSTRAINT_RESIDUE';end if;
if exists(select 1 from public.erp_permissions where key in('fiscal.read','fiscal.issue','fiscal.cancel','fiscal.configure','fiscal.certificate.manage','fiscal.audit'))then raise exception 'M13_0030_PERMISSION_RESIDUE';end if;
end$$;
select 'M13_0030_ZERO_RESIDUE_OK'result;
