begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(48);

select has_table('public','erp_capability_catalog','catalogo existe');
select has_table('public','erp_tenant_capability_entitlements','entitlements existem');
select has_table('public','erp_tenant_capability_exceptions','excecoes existem');
select has_function('public','erp_resolve_tenant_capabilities',array['uuid','timestamp with time zone'],'resolver existe');
select has_column('public','erp_capability_catalog','risk_level','catalogo possui risco');
select has_column('public','erp_tenant_capability_entitlements','tenant_id','entitlement tenant-scoped');
select has_column('public','erp_tenant_capability_entitlements','evidence_hash','entitlement possui evidencia');
select has_column('public','erp_tenant_capability_exceptions','approval_ref','excecao possui aprovacao opaca');
select has_column('public','erp_tenant_capability_exceptions','expires_at','excecao possui expiracao');
select ok((select relrowsecurity from pg_class where oid='public.erp_capability_catalog'::regclass),'RLS catalogo');
select ok((select relrowsecurity from pg_class where oid='public.erp_tenant_capability_entitlements'::regclass),'RLS entitlements');
select ok((select relrowsecurity from pg_class where oid='public.erp_tenant_capability_exceptions'::regclass),'RLS excecoes');
select is((select count(*)from public.erp_capability_catalog),12::bigint,'doze capacidades');
select is((select count(*)from public.erp_capability_catalog where risk_level='critical'),4::bigint,'quatro capacidades criticas');
select is((select count(*)from public.erp_capability_catalog where active),12::bigint,'catalogo ativo');
select ok(exists(select 1 from public.erp_permissions where key='capabilities.read'),'permissao leitura');
select ok(exists(select 1 from public.erp_permissions where key='capabilities.manage'),'permissao gestao');

insert into public.tenants(id,nome,slug,vertical)values
('16000000-0000-4000-8000-000000000001','SYNTHETIC M16G3 A','m16-g3-synthetic-a','synthetic-me'),
('16000000-0000-4000-8000-000000000002','SYNTHETIC M16G3 B','m16-g3-synthetic-b','synthetic-ltda');
insert into public.erp_tenant_capability_entitlements(tenant_id,capability_key,enabled,source,contract_version,effective_from,evidence_hash)values
('16000000-0000-4000-8000-000000000001','sales',true,'blueprint',1,'2026-01-01T00:00:00Z',repeat('a',64)),
('16000000-0000-4000-8000-000000000001','finance',true,'contract',1,'2026-01-01T00:00:00Z',repeat('b',64)),
('16000000-0000-4000-8000-000000000002','fiscal',true,'contract',1,'2026-01-01T00:00:00Z',repeat('c',64));
insert into public.erp_tenant_capability_exceptions(tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at)values
('16000000-0000-4000-8000-000000000001','finance','deny',repeat('d',64),'approval:synthetic-finance-deny','2026-01-01T00:00:00Z','2027-01-01T00:00:00Z'),
('16000000-0000-4000-8000-000000000001','inventory','allow',repeat('e',64),'approval:synthetic-inventory-allow','2026-01-01T00:00:00Z','2027-01-01T00:00:00Z');

select is((select count(*)from public.tenants where slug like'm16-g3-synthetic-%'),2::bigint,'dois tenants sinteticos');
select is((select count(*)from public.erp_tenant_capability_entitlements where tenant_id='16000000-0000-4000-8000-000000000001'),2::bigint,'entitlements isolados A');
select is((select count(*)from public.erp_tenant_capability_entitlements where tenant_id='16000000-0000-4000-8000-000000000002'),1::bigint,'entitlements isolados B');
select is((select count(*)from public.erp_tenant_capability_exceptions where tenant_id='16000000-0000-4000-8000-000000000001'),2::bigint,'excecoes isoladas A');
select is((select effect from public.erp_tenant_capability_exceptions where capability_key='finance'),'deny','negacao persistida');
select is((select effect from public.erp_tenant_capability_exceptions where capability_key='inventory'),'allow','permissao persistida');
select is((select source from public.erp_tenant_capability_entitlements where tenant_id='16000000-0000-4000-8000-000000000001'and capability_key='finance'),'contract','origem contratual');
select is((select contract_version from public.erp_tenant_capability_entitlements where tenant_id='16000000-0000-4000-8000-000000000001'and capability_key='sales'),1,'versao contratual');

select throws_ok($$insert into public.erp_tenant_capability_entitlements(tenant_id,capability_key,source,contract_version,effective_from,evidence_hash)values('16000000-0000-4000-8000-000000000001','unknown','contract',1,now(),repeat('f',64))$$,'23503',null,'capacidade desconhecida recusada');
select throws_ok($$insert into public.erp_tenant_capability_entitlements(tenant_id,capability_key,source,contract_version,effective_from,evidence_hash)values('16000000-0000-4000-8000-000000000001','cash','root',1,now(),repeat('f',64))$$,'23514',null,'origem invalida recusada');
select throws_ok($$insert into public.erp_tenant_capability_entitlements(tenant_id,capability_key,source,contract_version,effective_from,evidence_hash)values('16000000-0000-4000-8000-000000000001','cash','contract',0,now(),repeat('f',64))$$,'23514',null,'versao invalida recusada');
select throws_ok($$insert into public.erp_tenant_capability_entitlements(tenant_id,capability_key,source,contract_version,effective_from,evidence_hash)values('16000000-0000-4000-8000-000000000001','cash','contract',1,now(),'bad')$$,'23514',null,'hash invalido recusado');
select throws_ok($$insert into public.erp_tenant_capability_exceptions(tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at)values('16000000-0000-4000-8000-000000000001','cash','root',repeat('f',64),'approval:synthetic-invalid',now(),now()+interval'1 day')$$,'23514',null,'efeito invalido recusado');
select throws_ok($$insert into public.erp_tenant_capability_exceptions(tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at)values('16000000-0000-4000-8000-000000000001','cash','deny',repeat('f',64),'invalid',now(),now()+interval'1 day')$$,'23514',null,'aprovacao invalida recusada');
select throws_ok($$insert into public.erp_tenant_capability_exceptions(tenant_id,capability_key,effect,reason_hash,approval_ref,effective_from,expires_at)values('16000000-0000-4000-8000-000000000001','cash','deny',repeat('f',64),'approval:synthetic-expiry',now(),now())$$,'23514',null,'expiracao invalida recusada');
select throws_ok($$insert into public.erp_tenant_capability_entitlements(tenant_id,capability_key,source,contract_version,effective_from,evidence_hash)values('16000000-0000-4000-8000-000000000001','sales','contract',1,now(),repeat('f',64))$$,'23505',null,'versao duplicada recusada');

select is((select count(*)from pg_policies where schemaname='public'and tablename='erp_capability_catalog'),1::bigint,'uma policy catalogo');
select is((select count(*)from pg_policies where schemaname='public'and tablename='erp_tenant_capability_entitlements'),1::bigint,'uma policy entitlement');
select is((select count(*)from pg_policies where schemaname='public'and tablename='erp_tenant_capability_exceptions'),1::bigint,'uma policy excecao');
select ok(has_table_privilege('authenticated','public.erp_capability_catalog','SELECT'),'authenticated le catalogo');
select ok(has_table_privilege('authenticated','public.erp_tenant_capability_entitlements','SELECT'),'authenticated le entitlement sob RLS');
select ok(has_table_privilege('authenticated','public.erp_tenant_capability_exceptions','SELECT'),'authenticated le excecao sob RLS');
select ok(not has_table_privilege('authenticated','public.erp_tenant_capability_entitlements','INSERT'),'authenticated nao insere entitlement');
select ok(not has_table_privilege('authenticated','public.erp_tenant_capability_exceptions','UPDATE'),'authenticated nao altera excecao');
select ok(has_function_privilege('authenticated','public.erp_resolve_tenant_capabilities(uuid,timestamp with time zone)','EXECUTE'),'authenticated executa resolver protegido');
select ok(not has_function_privilege('anon','public.erp_resolve_tenant_capabilities(uuid,timestamp with time zone)','EXECUTE'),'anon nao executa resolver');
select ok(has_function_privilege('service_role','public.erp_resolve_tenant_capabilities(uuid,timestamp with time zone)','EXECUTE'),'service role executa resolver');
select is((select count(*)from public.erp_tenant_capability_entitlements where tenant_id='16000000-0000-4000-8000-000000000001'and evidence_hash~'^[a-f0-9]{64}$'),2::bigint,'evidencias validas');
select is((select count(*)from public.erp_tenant_capability_exceptions where tenant_id='16000000-0000-4000-8000-000000000001'and reason_hash~'^[a-f0-9]{64}$'),2::bigint,'razoes opacas validas');
select is((select count(*)from auth.users where email like'%m16-g3%'),0::bigint,'nenhuma conta criada');
select is((select count(*)from public.tenants where slug like'm16-g3-synthetic-%'),2::bigint,'fixtures completas antes do rollback');
select * from finish();
rollback;
