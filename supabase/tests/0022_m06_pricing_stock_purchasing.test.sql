begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(48);

select ok(to_regclass(format('public.%I',table_name)) is not null,format('tabela %s existe',table_name)) from unnest(array[
 'erp_price_lists','erp_price_items','erp_promotions','erp_stock_locations','erp_stock_lots','erp_stock_serials','erp_stock_movements','erp_stock_movement_items','erp_stock_reservations','erp_inventory_counts','erp_inventory_count_items','erp_purchase_orders','erp_purchase_order_items','erp_goods_receipts','erp_goods_receipt_items'
]) as names(table_name);
select ok(c.relrowsecurity,format('RLS ativo em %s',c.relname)) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array[
 'erp_price_lists','erp_price_items','erp_promotions','erp_stock_locations','erp_stock_lots','erp_stock_serials','erp_stock_movements','erp_stock_movement_items','erp_stock_reservations','erp_inventory_counts','erp_inventory_count_items','erp_purchase_orders','erp_purchase_order_items','erp_goods_receipts','erp_goods_receipt_items'
]) order by c.relname;
select ok(not has_table_privilege('anon',format('public.%I',t),'SELECT'),format('anon não lê %s',t)) from unnest(array['erp_price_lists','erp_stock_movements','erp_purchase_orders']) t;
select ok(has_table_privilege('authenticated',format('public.%I',t),'SELECT'),format('authenticated lê %s sob RLS',t)) from unnest(array['erp_price_lists','erp_stock_movements','erp_purchase_orders']) t;
select ok(not has_table_privilege('authenticated',format('public.%I',t),'DELETE'),format('authenticated não exclui %s',t)) from unnest(array['erp_price_lists','erp_stock_movements','erp_purchase_orders']) t;
select ok(not has_table_privilege('authenticated',format('public.%I',t),'UPDATE'),format('livro imutável %s',t)) from unnest(array['erp_stock_movements','erp_stock_movement_items']) t;
select is((select count(*)::integer from public.erp_permissions where key in('pricing.read','pricing.manage','stock.read','stock.manage','stock.count','purchasing.read','purchasing.manage','purchasing.receive')),8,'oito permissões M06 existem');
select ok(exists(select 1 from pg_constraint where conname='erp_stock_movements_tenant_id_idempotency_key_key'),'movimento é idempotente por tenant');
select ok(exists(select 1 from pg_constraint where conname='erp_goods_receipts_tenant_id_idempotency_key_key'),'recebimento é idempotente por tenant');
select ok(exists(select 1 from pg_constraint where conname='erp_stock_movement_items_quantity_delta_check'),'quantidade de movimento não é zero');
select ok(exists(select 1 from pg_constraint where conname='erp_stock_movement_items_check'),'série exige quantidade unitária');
select ok(exists(select 1 from pg_constraint where conname='erp_purchase_order_items_quantity_check'),'pedido exige quantidade positiva');
select ok(exists(select 1 from pg_constraint where conname='erp_price_items_price_check'),'preço não pode ser negativo');
select * from finish();
rollback;
