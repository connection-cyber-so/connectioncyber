begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(30);

create temporary table m15_g3_baseline(fiscal_count bigint) on commit drop;
insert into m15_g3_baseline select count(*) from public.erp_fiscal_documents;

insert into public.tenants(id,nome,slug,vertical) values
('15000000-0000-4000-8000-000000000001','SYNTHETIC M15G3 MEI','m15-g3-synthetic-mei','synthetic-mei'),
('15000000-0000-4000-8000-000000000002','SYNTHETIC M15G3 ME','m15-g3-synthetic-me','synthetic-me'),
('15000000-0000-4000-8000-000000000003','SYNTHETIC M15G3 LTDA','m15-g3-synthetic-ltda','synthetic-ltda');
insert into public.erp_establishments(id,tenant_id,code,kind,trade_name) values
('15100000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000001','SYNTHETIC','headquarters','SYNTHETIC M15G3 MEI'),
('15100000-0000-4000-8000-000000000002','15000000-0000-4000-8000-000000000002','SYNTHETIC','headquarters','SYNTHETIC M15G3 ME'),
('15100000-0000-4000-8000-000000000003','15000000-0000-4000-8000-000000000003','SYNTHETIC','headquarters','SYNTHETIC M15G3 LTDA');
insert into public.erp_parties(id,tenant_id,kind,legal_name) values('15200000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','person','SYNTHETIC CUSTOMER');
insert into public.erp_units(id,tenant_id,code,name) values
('15300000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','UN','SYNTHETIC UNIT'),
('15300000-0000-4000-8000-000000000002','15000000-0000-4000-8000-000000000003','UN','SYNTHETIC UNIT');
insert into public.erp_catalog_items(id,tenant_id,kind,code,name,base_unit_id,track_inventory) values('15400000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','product','SYNTHETIC-001','SYNTHETIC PRODUCT','15300000-0000-4000-8000-000000000001',true);
insert into public.erp_stock_locations(id,tenant_id,establishment_id,code,name) values('15500000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000002','SYNTHETIC','SYNTHETIC STOCK');
insert into public.erp_stock_movements(id,tenant_id,establishment_id,type,status,idempotency_key,notes) values('15600000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000002','opening','draft','m15g3:stock:1','SYNTHETIC STOCK MOVEMENT');
insert into public.erp_sales(id,tenant_id,establishment_id,customer_id,code,status,subtotal,grand_total,idempotency_key) values('15700000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000002','15200000-0000-4000-8000-000000000001','SYNTHETIC-SALE-001','draft',10,10,'m15g3:sale:1');
insert into public.erp_cash_registers(id,tenant_id,establishment_id,code,name) values('15800000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000002','SYNTHETIC','SYNTHETIC CASH');
insert into public.erp_financial_accounts(id,tenant_id,establishment_id,code,name,kind) values('15900000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000002','SYNTHETIC','SYNTHETIC ACCOUNT','cash');
insert into public.erp_financial_entries(id,tenant_id,establishment_id,party_id,code,direction,status,principal_amount,issue_date,due_date,idempotency_key,notes) values('15a00000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000002','15200000-0000-4000-8000-000000000001','SYNTHETIC-FIN-001','receivable','draft',10,current_date,current_date,'m15g3:finance:1','SYNTHETIC FINANCE');

select is((select count(*) from public.tenants where vertical='synthetic-mei'),1::bigint,'perfil MEI sintético criado');
select is((select count(*) from public.tenants where vertical='synthetic-me'),1::bigint,'perfil ME sintético criado');
select is((select count(*) from public.tenants where vertical='synthetic-ltda'),1::bigint,'perfil LTDA sintético criado');
select is((select count(*) from public.erp_establishments where tenant_id::text like '15000000-0000-4000-8000-00000000000%'),3::bigint,'três estabelecimentos sintéticos');
select is((select count(*) from public.erp_parties where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'cadastro sintético');
select is((select count(*) from public.erp_units where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'unidade sintética');
select is((select count(*) from public.erp_catalog_items where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'catálogo sintético');
select is((select count(*) from public.erp_stock_locations where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'local de estoque sintético');
select is((select count(*) from public.erp_stock_movements where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'movimento de estoque sintético');
select is((select count(*) from public.erp_sales where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'venda sintética');
select is((select count(*) from public.erp_cash_registers where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'caixa sintético');
select is((select count(*) from public.erp_financial_accounts where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'conta financeira sintética');
select is((select count(*) from public.erp_financial_entries where tenant_id='15000000-0000-4000-8000-000000000002'),1::bigint,'título sintético');
select is((select count(*) from public.erp_parties where tenant_id='15000000-0000-4000-8000-000000000002' and tax_id is null),1::bigint,'fixture sem documento fiscal');
select is((select count(*) from public.tenants where slug like 'm15-g3-synthetic-%' and nome like 'SYNTHETIC%'),3::bigint,'fixtures explicitamente sintéticas');

select throws_ok($$insert into public.erp_sales(tenant_id,establishment_id,customer_id,code,idempotency_key)values('15000000-0000-4000-8000-000000000003','15100000-0000-4000-8000-000000000003','15200000-0000-4000-8000-000000000001','CROSS','m15g3:cross:sale')$$,'23503',null,'venda recusa cliente de outro tenant');
select throws_ok($$insert into public.erp_stock_locations(tenant_id,establishment_id,code,name)values('15000000-0000-4000-8000-000000000002','15100000-0000-4000-8000-000000000003','CROSS','SYNTHETIC CROSS')$$,'23503',null,'estoque recusa estabelecimento de outro tenant');
select throws_ok($$insert into public.erp_financial_entries(tenant_id,establishment_id,party_id,code,direction,principal_amount,issue_date,due_date,idempotency_key)values('15000000-0000-4000-8000-000000000003','15100000-0000-4000-8000-000000000003','15200000-0000-4000-8000-000000000001','CROSS','receivable',1,current_date,current_date,'m15g3:cross:finance')$$,'23503',null,'financeiro recusa parte de outro tenant');
select throws_ok($$insert into public.erp_catalog_items(tenant_id,kind,code,name,base_unit_id)values('15000000-0000-4000-8000-000000000002','product','CROSS','SYNTHETIC CROSS','15300000-0000-4000-8000-000000000002')$$,'23503',null,'catálogo recusa unidade de outro tenant');

select ok(c.relrowsecurity,format('RLS ativa em %s',c.relname)) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname=any(array['erp_parties','erp_catalog_items','erp_stock_movements','erp_sales','erp_cash_registers','erp_financial_entries','erp_fiscal_documents']) order by c.relname;
select is((select count(*) from public.erp_fiscal_documents),(select fiscal_count from m15_g3_baseline),'fiscal permanece inalterado');
select is((select count(*) from auth.users where email like '%m15-g3%'),0::bigint,'nenhuma conta sintética criada');
select is((select count(*) from public.erp_fiscal_documents where tenant_id in('15000000-0000-4000-8000-000000000001','15000000-0000-4000-8000-000000000002','15000000-0000-4000-8000-000000000003')),0::bigint,'nenhum documento fiscal criado');
select is((select count(*) from public.tenants where slug like 'm15-g3-synthetic-%'),3::bigint,'fixtures completas antes do rollback');
select * from finish();
rollback;
