begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(6);

insert into public.tenants(nome,slug,vertical) values ('M20 G5 Synthetic','m20-g5-synthetic','teste') on conflict (slug) do nothing;
insert into public.erp_units(tenant_id,code,name) values ((select id from public.tenants where slug='m20-g5-synthetic'),'UN','Unidade') on conflict (tenant_id,code) do nothing;
insert into public.erp_catalog_items(tenant_id,kind,code,name,base_unit_id) values (
  (select id from public.tenants where slug='m20-g5-synthetic'),
  'product','M20-G5-ITEM-A','Item Sintetico A',
  (select id from public.erp_units where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='UN')
) on conflict (tenant_id,code) do nothing;

select ok(exists(
  select 1 from information_schema.columns
  where table_schema='public' and table_name='erp_item_fiscal_data' and column_name='cst_ibs_cbs'
),'coluna cst_ibs_cbs existe');
select ok(exists(
  select 1 from information_schema.columns
  where table_schema='public' and table_name='erp_item_fiscal_data' and column_name='cclass_trib'
),'coluna cclass_trib existe');
select ok((
  select is_nullable='YES' from information_schema.columns
  where table_schema='public' and table_name='erp_item_fiscal_data' and column_name='cst_ibs_cbs'
),'cst_ibs_cbs é opcional (não força preenchimento agora)');
select ok((
  select is_nullable='YES' from information_schema.columns
  where table_schema='public' and table_name='erp_item_fiscal_data' and column_name='cclass_trib'
),'cclass_trib é opcional (não força preenchimento agora)');

insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code) values (
  (select id from public.tenants where slug='m20-g5-synthetic'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-A'),
  '61091000','CSOSN','102'
);
select ok(exists(
  select 1 from public.erp_item_fiscal_data fd join public.tenants t on t.id=fd.tenant_id
  where t.slug='m20-g5-synthetic' and fd.cst_ibs_cbs is null and fd.cclass_trib is null
),'item existente sem os códigos da reforma continua válido (compatibilidade)');

update public.erp_item_fiscal_data set cst_ibs_cbs='200', cclass_trib='000001'
where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic')
  and item_id=(select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g5-synthetic') and code='M20-G5-ITEM-A');
select ok(exists(
  select 1 from public.erp_item_fiscal_data fd join public.tenants t on t.id=fd.tenant_id
  where t.slug='m20-g5-synthetic' and fd.cst_ibs_cbs='200' and fd.cclass_trib='000001'
),'preencher CST/cClassTrib do IBS-CBS com formato válido funciona');

select * from finish();
rollback;
