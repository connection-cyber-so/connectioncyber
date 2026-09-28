select jsonb_build_object(
  'dining_areas',(select count(*) from public.erp_dining_areas),
  'dining_tables',(select count(*) from public.erp_dining_tables),
  'table_sessions',(select count(*) from public.erp_table_sessions),
  'food_tabs',(select count(*) from public.erp_food_tabs),
  'food_orders',(select count(*) from public.erp_food_orders),
  'kitchen_tickets',(select count(*) from public.erp_kitchen_tickets),
  'sales_from_food',(select count(*) from public.erp_sales where idempotency_key like '%:sale')
) as m10_row_counts;
