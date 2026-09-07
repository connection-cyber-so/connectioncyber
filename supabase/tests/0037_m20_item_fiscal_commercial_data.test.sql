begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(20);

-- fixtures sintéticos (dois tenants, nunca persistidos — toda a validação roda dentro
-- de uma transação com ROLLBACK no fim do arquivo gerado por
-- supabase/validation/build-0037-transaction.mjs).
insert into public.tenants(nome,slug,vertical) values ('M20 G1 Synthetic A','m20-g1-synthetic-a','teste') on conflict (slug) do nothing;
insert into public.tenants(nome,slug,vertical) values ('M20 G1 Synthetic B','m20-g1-synthetic-b','teste') on conflict (slug) do nothing;
insert into public.erp_units(tenant_id,code,name) values ((select id from public.tenants where slug='m20-g1-synthetic-a'),'UN','Unidade') on conflict (tenant_id,code) do nothing;
insert into public.erp_catalog_items(tenant_id,kind,code,name,base_unit_id) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  'product','M20-G1-ITEM-A','Item Sintetico A',
  (select id from public.erp_units where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='UN')
) on conflict (tenant_id,code) do nothing;

select ok(to_regclass('public.erp_item_fiscal_data') is not null,'tabela erp_item_fiscal_data existe');
select ok(to_regclass('public.erp_item_commercial_data') is not null,'tabela erp_item_commercial_data existe');

select ok(c.relrowsecurity,format('RLS ativo em %s',c.relname))
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname=any(array['erp_item_fiscal_data','erp_item_commercial_data'])
order by c.relname;

select ok(not has_table_privilege('anon','public.erp_item_fiscal_data','SELECT'),'anon não lê dado fiscal');
select ok(not has_table_privilege('anon','public.erp_item_commercial_data','SELECT'),'anon não lê dado comercial');
select ok(has_table_privilege('authenticated','public.erp_item_fiscal_data','SELECT'),'authenticated possui grant filtrado por RLS (fiscal)');
select ok(has_table_privilege('authenticated','public.erp_item_commercial_data','SELECT'),'authenticated possui grant filtrado por RLS (comercial)');
select ok(not has_table_privilege('authenticated','public.erp_item_fiscal_data','DELETE'),'dado fiscal usa exclusão só por cascade');
select ok(not has_table_privilege('authenticated','public.erp_item_commercial_data','DELETE'),'dado comercial usa exclusão só por cascade');

select is((select count(*)::integer from public.erp_permissions where key in ('fiscal.item.read','fiscal.item.manage')),2,'duas permissões fiscal.item.* existem');

select ok(exists(select 1 from pg_constraint where conname='erp_item_fiscal_data_tenant_id_unique'),'dado fiscal possui chave composta tenant');
select ok(exists(select 1 from pg_constraint where conname='erp_item_commercial_data_tenant_id_unique'),'dado comercial possui chave composta tenant');

select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.erp_item_fiscal_data'::regclass and contype='f' and confrelid='public.erp_catalog_items'::regclass
),'FK dado fiscal -> catálogo existe');
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.erp_item_commercial_data'::regclass and contype='f' and confrelid='public.erp_catalog_items'::regclass
),'FK dado comercial -> catálogo existe');

select ok(exists(select 1 from pg_trigger where tgrelid='public.erp_item_fiscal_data'::regclass and tgname='trg_erp_item_fiscal_data_updated_at'),'trigger updated_at existe (fiscal)');
select ok(exists(select 1 from pg_trigger where tgrelid='public.erp_item_commercial_data'::regclass and tgname='trg_erp_item_commercial_data_updated_at'),'trigger updated_at existe (comercial)');

insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,tax_code_kind,tax_code,icms_rate,gross_weight,net_weight) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A'),
  '61091000','CSOSN','102',18,0.500,0.450
);
select ok(exists(select 1 from public.erp_item_fiscal_data where ncm='61091000'),'insert fiscal válido (CSOSN 102) é aceito');

insert into public.erp_item_commercial_data(tenant_id,item_id,cost_price,margin_percent,suggested_sale_price,min_stock_quantity,reorder_point) values (
  (select id from public.tenants where slug='m20-g1-synthetic-a'),
  (select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A'),
  25.00,60,40.00,5,10
);
select ok(exists(select 1 from public.erp_item_commercial_data where cost_price=25.00),'insert comercial válido é aceito');

update public.erp_item_commercial_data set cost_price=26.00
where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a')
  and item_id=(select id from public.erp_catalog_items where tenant_id=(select id from public.tenants where slug='m20-g1-synthetic-a') and code='M20-G1-ITEM-A');
-- now() fica congelado no início da transação (mesmo valor em created_at e updated_at
-- dentro de um único BEGIN/ROLLBACK de validação) — por isso a checagem é estrutural
-- (função certa, disparo BEFORE UPDATE FOR EACH ROW), não comportamental por timestamp.
select ok(exists(
  select 1 from pg_trigger
  where tgrelid='public.erp_item_commercial_data'::regclass
    and tgname='trg_erp_item_commercial_data_updated_at'
    and tgfoid='public.set_updated_at()'::regprocedure
    and tgtype & 1 = 1  -- ROW
    and tgtype & 2 = 2  -- BEFORE
    and tgtype & 16 = 16 -- UPDATE
),'trigger comercial dispara set_updated_at antes de UPDATE por linha');

select * from finish();
rollback;
