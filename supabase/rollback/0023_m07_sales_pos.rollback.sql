-- Somente laboratório vazio. Em ambiente com uso, aplicar forward-fix.
begin;
do $$ begin if exists(select 1 from public.erp_sales) or exists(select 1 from public.erp_quotes) or exists(select 1 from public.erp_cash_sessions) then raise exception 'Rollback recusado: há dados M07'; end if; end $$;
drop function if exists public.erp_complete_sale(uuid,uuid,text),public.erp_open_cash_session(uuid,uuid,numeric,text);
drop table if exists public.erp_sale_receipts,public.erp_return_items,public.erp_returns,public.erp_cash_movements,public.erp_sale_payments,public.erp_sale_items,public.erp_sales,public.erp_cash_sessions,public.erp_cash_registers,public.erp_payment_methods,public.erp_sales_order_items,public.erp_sales_orders,public.erp_quote_items,public.erp_quotes cascade;
delete from public.erp_permissions where key in('sales.read','sales.quote','sales.order','sales.complete','sales.return','sales.discount','payments.read','payments.manage','payments.refund','cash.read','cash.operate','cash.close','cash.adjust');
commit;
