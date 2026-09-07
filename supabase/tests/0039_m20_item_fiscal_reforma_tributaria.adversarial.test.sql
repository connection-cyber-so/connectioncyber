begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(4);

-- reaproveita o fixture do teste estrutural (mesma transação): tenant
-- m20-g5-synthetic e o item M20-G5-ITEM-A já têm fiscal válido.
insert into public.erp_catalog_items(tenant_id,kind,code,name,base_unit_id) values (
  (select id from public.tenants where slug='m20-g5-synthetic'),
  'product','M20-G5-ITEM-B','Item Sintetico B (alvo de tentativas rejeitadas)',
  (select id from public.erp_units where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='UN')
) on conflict (tenant_id,code) do nothing;
insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g5-synthetic'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-B'),
  '61091000','CSOSN','102'
);

select throws_ok($$update public.erp_item_fiscal_data set cst_ibs_cbs='12'
  where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic')
    and item_id=(select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-B')$$,
  '23514');

select throws_ok($$update public.erp_item_fiscal_data set cst_ibs_cbs='2A0'
  where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic')
    and item_id=(select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-B')$$,
  '23514');

select throws_ok($$update public.erp_item_fiscal_data set cclass_trib='12345'
  where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic')
    and item_id=(select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-B')$$,
  '23514');

select throws_ok($$update public.erp_item_fiscal_data set cclass_trib='ABCDEF'
  where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic')
    and item_id=(select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-B')$$,
  '23514');

select * from finish();
rollback;
