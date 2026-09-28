begin transaction read only;

select 'M18_G12_PERSISTENT_READ_ONLY_OK' as marker
where not exists (
  select 1 from public.tenants where id = '00000000-0000-4000-8000-000000000018'::uuid
)
and not exists (
  select 1 from public.erp_command_receipts where tenant_id = '00000000-0000-4000-8000-000000000018'::uuid
)
and (
  select count(*)
  from pg_catalog.pg_proc
  where pronamespace = 'public'::regnamespace
    and proname in (
      'erp_command_create_party_v1',
      'erp_command_create_catalog_item_v1',
      'erp_command_receive_inventory_v1',
      'erp_command_open_cash_v1',
      'erp_command_complete_sale_v1',
      'erp_command_settle_receivable_v1',
      'erp_command_close_cash_v1'
    )
) = 7
and not exists (
  select 1
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'erp_parties', 'erp_catalog_items', 'erp_stock_movement_items',
      'erp_cash_sessions', 'erp_sales', 'erp_financial_entries',
      'erp_installments', 'erp_command_receipts'
    )
    and not c.relrowsecurity
);

rollback;
