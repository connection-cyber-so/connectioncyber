-- Somente laboratório vazio. Em ambiente com uso, aplicar forward-fix.
begin;
do $$ begin
 if exists(select 1 from public.erp_stock_movements) or exists(select 1 from public.erp_purchase_orders) or exists(select 1 from public.erp_price_lists) then raise exception 'Rollback recusado: há dados M06'; end if;
end $$;
drop table if exists public.erp_goods_receipt_items,public.erp_goods_receipts,public.erp_purchase_order_items,public.erp_purchase_orders,public.erp_inventory_count_items,public.erp_inventory_counts,public.erp_stock_reservations,public.erp_stock_movement_items,public.erp_stock_movements,public.erp_stock_serials,public.erp_stock_lots,public.erp_stock_locations,public.erp_promotions,public.erp_price_items,public.erp_price_lists cascade;
delete from public.erp_permissions where key in('pricing.read','pricing.manage','stock.read','stock.manage','stock.count','purchasing.read','purchasing.manage','purchasing.receive');
commit;
