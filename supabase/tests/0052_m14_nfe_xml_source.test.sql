begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(16);

-- Fixture: tenant sintetico de teste (nunca dado real).
insert into public.tenants(nome,slug,vertical,dominio)
 values('M14 Teste 0052','m14-teste-0052','synthetic-test','m14teste0052.invalid');

-- 1-2: estrutura da RPC apos a 0052.
select ok(to_regprocedure('public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)') is not null,
 'rpc de registro de manifesto existe');
select ok(exists(select 1 from pg_proc where proname='erp_register_import_manifest'
 and pg_get_functiondef(oid) like '%nfe_xml%'),
 'definicao da rpc aceita nfe_xml');

-- 3-4: check da tabela aceita nfe_xml e continua recusando fonte desconhecida.
select lives_ok($$insert into public.erp_import_manifests(tenant_id,idempotency_key,source_type,source_sha256,schema_version,captured_at)
 select id,'m14-0052-direct-nfe-xml-v1','nfe_xml',repeat('a',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz
 from public.tenants where slug='m14-teste-0052'$$,
 'check da tabela aceita source_type nfe_xml');
select throws_ok($$insert into public.erp_import_manifests(tenant_id,idempotency_key,source_type,source_sha256,schema_version,captured_at)
 select id,'m14-0052-direct-xml-export-v1','xml_export',repeat('c',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz
 from public.tenants where slug='m14-teste-0052'$$,
 '23514',null,'check da tabela recusa source_type fora do allowlist');

-- Sessao broker: claims de service_role (a RPC exige auth.role()='service_role').
select set_config('request.jwt.claims','{"role":"service_role"}',true);

-- 5-6: rpc registra nfe_xml e o replay devolve o mesmo id.
select lives_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-nfe-xml-v1',
 'nfe_xml',repeat('b',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,
 '{"source_system":"SICNET"}'::jsonb)$$,
 'rpc registra manifesto com source_type nfe_xml');
select is(
 (select public.erp_register_import_manifest(
   (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-nfe-xml-v1',
   'nfe_xml',repeat('b',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,
   '{"source_system":"SICNET"}'::jsonb)),
 (select public.erp_register_import_manifest(
   (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-nfe-xml-v1',
   'nfe_xml',repeat('b',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,
   '{"source_system":"SICNET"}'::jsonb)),
 'replay idempotente devolve o mesmo manifesto');

-- 7-8: conflito de idempotencia e fonte desconhecida continuam bloqueados.
select throws_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-nfe-xml-v1',
 'nfe_xml',repeat('d',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,
 '{"source_system":"SICNET"}'::jsonb)$$,
 'P0001','manifest idempotency conflict','replay com hash divergente conflita');
select throws_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-bad-source-v1',
 'xml_export',repeat('e',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,'{}'::jsonb)$$,
 'P0001','invalid manifest','rpc recusa source_type fora do allowlist');

-- 9-10: regressao das fontes legadas da 0031.
select lives_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-json-export-v1',
 'json_export',repeat('f',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,'{}'::jsonb)$$,
 'fonte legada json_export continua aceita');
select lives_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-sqlserver-backup-v1',
 'sqlserver_backup',repeat('0',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,'{}'::jsonb)$$,
 'fonte legada sqlserver_backup continua aceita');

-- 11-12: allowlist de metadata e bloqueio de source_path intactos.
select throws_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-bad-meta-v1',
 'nfe_xml',repeat('1',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,
 '{"unknown_key":"x"}'::jsonb)$$,
 'P0001','secret, source path or unknown metadata forbidden','metadata com chave fora da allowlist recusada');
select throws_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-srcpath-v1',
 'nfe_xml',repeat('2',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,
 '{"source_path":"C:\\dados"}'::jsonb)$$,
 'P0001','secret, source path or unknown metadata forbidden','metadata com source_path recusada');

-- 13-14: a RPC continua broker-only.
select set_config('request.jwt.claims','{"role":"anon"}',true);
select throws_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-anon-v1',
 'nfe_xml',repeat('3',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,'{}'::jsonb)$$,
 'P0001','broker only','anon nao chama a rpc de manifesto');
select set_config('request.jwt.claims','{"role":"authenticated"}',true);
select throws_ok($$select public.erp_register_import_manifest(
 (select id from public.tenants where slug='m14-teste-0052'),'m14-0052-rpc-auth-v1',
 'nfe_xml',repeat('4',64),'legacy-sicnet-nfe-v1','2026-09-28T12:00:00-03:00'::timestamptz,'{}'::jsonb)$$,
 'P0001','broker only','authenticated nao chama a rpc de manifesto');

-- 15-16: grants e RLS do ledger inalterados.
select ok(has_function_privilege('service_role','public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)','execute')
 and not has_function_privilege('anon','public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)','execute')
 and not has_function_privilege('authenticated','public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)','execute'),
 'grant da rpc inalterado: somente service_role executa');
select ok((select relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname='erp_import_manifests')
 and (select count(*) from pg_policies where schemaname='public' and tablename='erp_import_manifests')=1,
 'RLS ativo e unica policy select inalterados na tabela de manifestos');

select * from finish();
rollback;
