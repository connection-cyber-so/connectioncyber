do $$
declare n text;
begin
  foreach n in array array['tenants','erp_parties','erp_catalog_items','erp_stock_movements','erp_stock_movement_items','erp_cash_sessions','erp_cash_movements','erp_sales','erp_financial_entries','erp_settlements','erp_tenant_capabilities']loop if to_regclass('public.'||n)is null then raise exception 'missing dependency: %',n;end if;end loop;
  if to_regclass('public.erp_command_receipts')is not null then raise exception '0033 already present';end if;
  if to_regprocedure('public.erp_create_party(uuid,text,text,text,text,text)')is null or to_regprocedure('public.erp_open_cash_session(uuid,uuid,numeric,text)')is null or to_regprocedure('public.erp_complete_sale(uuid,uuid,text)')is null or to_regprocedure('public.erp_confirm_settlement(uuid,uuid,text)')is null or to_regprocedure('public.erp_resolve_tenant_capabilities(uuid,timestamp with time zone)')is null then raise exception 'required baseline RPC missing';end if;
  if to_regprocedure('extensions.digest(bytea,text)')is null then raise exception 'pgcrypto digest missing from extensions schema';end if;
end$$;
select 'M17_0033_PREFLIGHT_OK' as result;
