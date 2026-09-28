select jsonb_build_object(
  'assets',(select count(*) from public.erp_assets),
  'appointments',(select count(*) from public.erp_appointments),
  'service_orders',(select count(*) from public.erp_service_orders),
  'service_order_items',(select count(*) from public.erp_service_order_items),
  'sales_from_services',(select count(*) from public.erp_sales where idempotency_key like '%:sale'),
  'warranties',(select count(*) from public.erp_service_warranties)
) as m09_row_counts;
