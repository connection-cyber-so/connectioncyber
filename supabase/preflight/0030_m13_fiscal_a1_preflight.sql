do $$begin
if current_setting('server_version_num')::integer<150000 then raise exception 'PostgreSQL 15+ obrigatório';end if;
if to_regprocedure('erp_security.current_aal()')is null or to_regprocedure('erp_security.has_permission(uuid,text)')is null or to_regclass('public.erp_establishments')is null or to_regclass('public.erp_sales')is null then raise exception 'M02/M04/M07 ausente';end if;
if to_regclass('public.erp_fiscal_documents')is not null or to_regprocedure('public.erp_reserve_fiscal_number(uuid,uuid,text,text,integer,text)')is not null then raise exception 'Objetos M13 já existem sem histórico 0030';end if;
if exists(select 1 from public.erp_permissions where key in('fiscal.read','fiscal.issue','fiscal.cancel','fiscal.configure','fiscal.certificate.manage','fiscal.audit')and category<>'Fiscal')then raise exception 'Colisão de permissões M13';end if;
end$$;
select now()checked_at,'M13_0030_PREFLIGHT_OK'result;
