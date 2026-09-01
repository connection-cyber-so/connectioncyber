begin;
set transaction read only;

do $$
declare
  missing text;
begin
  select string_agg(name, ', ' order by name) into missing
  from unnest(array[
    'erp_command_create_party_v1(uuid,text,text,jsonb)',
    'erp_command_create_catalog_item_v1(uuid,text,text,jsonb)',
    'erp_command_receive_inventory_v1(uuid,text,text,jsonb)',
    'erp_command_open_cash_v1(uuid,text,text,jsonb)',
    'erp_command_complete_sale_v1(uuid,text,text,jsonb)',
    'erp_command_settle_receivable_v1(uuid,text,text,jsonb)',
    'erp_command_close_cash_v1(uuid,text,text,jsonb)'
  ]) as required(name)
  where to_regprocedure('public.' || name) is null;
  if missing is not null then raise exception 'missing M18 RPCs: %', missing; end if;

  select string_agg(name, ', ' order by name) into missing
  from unnest(array[
    'erp_command_receipts','erp_parties','erp_party_roles','erp_catalog_items','erp_units',
    'erp_stock_movements','erp_stock_movement_items','erp_cash_sessions','erp_sales',
    'erp_financial_entries','erp_installments'
  ]) as required(name)
  where to_regclass('public.' || name) is null;
  if missing is not null then raise exception 'missing M18 relations: %', missing; end if;

  select string_agg(name, ', ' order by name) into missing
  from unnest(array[
    'erp_command_receipts','erp_parties','erp_party_roles','erp_catalog_items','erp_units',
    'erp_stock_movements','erp_stock_movement_items','erp_cash_sessions','erp_sales',
    'erp_financial_entries','erp_installments'
  ]) as required(name)
  left join pg_class c on c.oid = to_regclass('public.' || required.name)
  where not coalesce(c.relrowsecurity, false);
  if missing is not null then raise exception 'RLS disabled: %', missing; end if;

  select string_agg(required.table_name || '.' || required.column_name, ', ' order by required.table_name, required.column_name) into missing
  from (values
    ('erp_parties','tenant_id'),('erp_parties','legal_name'),('erp_party_roles','role'),
    ('erp_catalog_items','tenant_id'),('erp_catalog_items','base_unit_id'),
    ('erp_stock_movement_items','tenant_id'),('erp_stock_movement_items','quantity_delta'),
    ('erp_cash_sessions','tenant_id'),('erp_cash_sessions','expected_amount'),
    ('erp_sales','tenant_id'),('erp_sales','grand_total'),
    ('erp_financial_entries','tenant_id'),('erp_financial_entries','principal_amount'),
    ('erp_installments','tenant_id'),('erp_installments','principal_amount')
  ) as required(table_name,column_name)
  left join information_schema.columns c on c.table_schema='public' and c.table_name=required.table_name and c.column_name=required.column_name
  where c.column_name is null;
  if missing is not null then raise exception 'missing adapter columns: %', missing; end if;

  select string_agg(name, ', ' order by name) into missing
  from unnest(array['erp_parties','erp_party_roles','erp_catalog_items','erp_units','erp_stock_movements','erp_stock_movement_items','erp_cash_sessions','erp_sales','erp_financial_entries','erp_installments']) as required(name)
  where not has_table_privilege('authenticated', 'public.' || name, 'SELECT') or has_table_privilege('anon', 'public.' || name, 'SELECT');
  if missing is not null then raise exception 'unsafe read grants: %', missing; end if;

  select string_agg(name, ', ' order by name) into missing
  from unnest(array[
    'erp_command_create_party_v1(uuid,text,text,jsonb)','erp_command_create_catalog_item_v1(uuid,text,text,jsonb)',
    'erp_command_receive_inventory_v1(uuid,text,text,jsonb)','erp_command_open_cash_v1(uuid,text,text,jsonb)',
    'erp_command_complete_sale_v1(uuid,text,text,jsonb)','erp_command_settle_receivable_v1(uuid,text,text,jsonb)',
    'erp_command_close_cash_v1(uuid,text,text,jsonb)'
  ]) as required(name)
  where not has_function_privilege('authenticated', 'public.' || name, 'EXECUTE') or has_function_privilege('anon', 'public.' || name, 'EXECUTE');
  if missing is not null then raise exception 'unsafe RPC grants: %', missing; end if;
end $$;

select 'M18_G8_READ_ONLY_PREFLIGHT_OK' as result;
rollback;
