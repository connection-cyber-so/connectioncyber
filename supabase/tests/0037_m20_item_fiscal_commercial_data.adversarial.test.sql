begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(12);

-- reaproveita os fixtures do teste estrutural (mesma transação): tenants
-- m20-g1-synthetic-a/-b e o item M20-G1-ITEM-A já têm fiscal+comercial válidos.
insert into public.erp_catalog_items(tenant_id,kind,code,name,base_unit_id) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  'product','M20-G1-ITEM-B','Item Sintetico B',
  (select id from public.erp_units where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='UN')
) on conflict (tenant_id,code) do nothing;
insert into public.erp_catalog_items(tenant_id,kind,code,name,base_unit_id) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  'product','M20-G1-ITEM-C','Item Sintetico C (alvo de tentativas rejeitadas)',
  (select id from public.erp_units where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='UN')
) on conflict (tenant_id,code) do nothing;

select throws_ok($$insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A'),
  '61091000','CSOSN','102')$$,
  '23505');

select throws_ok($$insert into public.erp_item_commercial_data(tenant_id,item_id,cost_price) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A'),
  10.00)$$,
  '23505');

select throws_ok($$insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-C'),
  '123456','CSOSN','102')$$,
  '23514');

select throws_ok($$insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-C'),
  '61091000','CST','101')$$,
  '23514');

insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-B'),
  '61091000','CST','00'
);
select ok(exists(select 1 from public.erp_item_fiscal_data where tax_code_kind='CST' and tax_code='00'),'CST 00 (regime normal) é aceito');

select throws_ok($$insert into public.erp_item_commercial_data(tenant_id,item_id,cost_price) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-C'),
  -1.00)$$,
  '23514');

select throws_ok($$insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code,gross_weight,net_weight) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-C'),
  '61091000','CSOSN','102',0.100,0.900)$$,
  '23514');

select throws_ok($$insert into public.erp_item_commercial_data(tenant_id,item_id,cost_price,min_stock_quantity,reorder_point) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-C'),
  10.00,20,5)$$,
  '23514');

select throws_ok($$insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g1-synthetic-b'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A'),
  '61091000','CSOSN','102')$$,
  '23503');

select ok(not has_table_privilege('anon','public.erp_item_fiscal_data','INSERT'),'anon não pode inserir dado fiscal, nem forjando tenant_id');

delete from public.erp_catalog_items
where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A';

select ok(not exists(select 1 from public.erp_item_fiscal_data fd join public.tenants t on t.id=fd.tenant_id where t.slug='m20-g1-synthetic-a' and fd.tax_code='102'),'cascade remove dado fiscal ao apagar o item');
select ok(not exists(select 1 from public.erp_item_commercial_data cd join public.tenants t on t.id=cd.tenant_id where t.slug='m20-g1-synthetic-a' and cd.cost_price=26.00),'cascade remove dado comercial ao apagar o item');

select * from finish();
rollback;
