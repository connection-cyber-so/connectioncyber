begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(25);

-- Fixtures M24: donos com fiscal.deliver em A e B, contador no tenant C, sempre sintetico.
insert into public.tenants (id,nome,slug,vertical,ativo) values
 ('9a000000-0000-4000-8000-000000000001','M24 Tenant A','m24-synthetic-a','varejo',true),
 ('9a000000-0000-4000-8000-000000000002','M24 Tenant B','m24-synthetic-b','servicos',true),
 ('9a000000-0000-4000-8000-000000000003','M24 Tenant C','m24-synthetic-c','varejo',true);
insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('9b000000-0000-4000-8000-000000000001','authenticated','authenticated','m24-owner-a@example.invalid','',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"nome":"M24 Owner A","tenant_id":"9a000000-0000-4000-8000-000000000001"}'::jsonb,now(),now()),
 ('9b000000-0000-4000-8000-000000000002','authenticated','authenticated','m24-owner-b@example.invalid','',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"nome":"M24 Owner B","tenant_id":"9a000000-0000-4000-8000-000000000002"}'::jsonb,now(),now()),
 ('9c000000-0000-4000-8000-000000000001','authenticated','authenticated','m24-accountant@example.invalid','',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"nome":"M24 Contador","tenant_id":"9a000000-0000-4000-8000-000000000003"}'::jsonb,now(),now());
insert into public.erp_tenant_memberships (id,tenant_id,user_id,status,is_default) values
 ('9d000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000001','9b000000-0000-4000-8000-000000000001','active',true),
 ('9d000000-0000-4000-8000-000000000002','9a000000-0000-4000-8000-000000000002','9b000000-0000-4000-8000-000000000002','active',true);
insert into public.erp_roles (id,tenant_id,key,name) values
 ('9e000000-0000-4000-8000-000000000001','9a000000-0000-4000-8000-000000000001','operator','Operador A'),
 ('9e000000-0000-4000-8000-000000000002','9a000000-0000-4000-8000-000000000002','operator','Operador B');
insert into public.erp_membership_roles (tenant_id,membership_id,role_id) values
 ('9a000000-0000-4000-8000-000000000001','9d000000-0000-4000-8000-000000000001','9e000000-0000-4000-8000-000000000001'),
 ('9a000000-0000-4000-8000-000000000002','9d000000-0000-4000-8000-000000000002','9e000000-0000-4000-8000-000000000002');
insert into public.erp_role_permissions (tenant_id,role_id,permission_id)
 select r.tenant_id::uuid,r.role_id::uuid,p.id
 from public.erp_permissions p
  cross join (values ('9a000000-0000-4000-8000-000000000001','9e000000-0000-4000-8000-000000000001'),
                     ('9a000000-0000-4000-8000-000000000002','9e000000-0000-4000-8000-000000000002')) as r(tenant_id,role_id)
 where p.key='fiscal.deliver';
insert into public.user_roles (user_id,role_id)
 values ('9c000000-0000-4000-8000-000000000001',(select id from public.roles where nome='contador'));

-- Dono A (sem fiscal.deliver): publicacao negada (fail closed).
select set_config('request.jwt.claims','{"sub":"9b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','9b000000-0000-4000-8000-000000000001',true);
delete from public.erp_role_permissions where tenant_id='9a000000-0000-4000-8000-000000000001'
 and role_id='9e000000-0000-4000-8000-000000000001'
 and permission_id=(select id from public.erp_permissions where key='fiscal.deliver');
select throws_ok(
 $$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-09-01',
   '[{"file_name":"a.xml","storage_path":"x/2026-09/a.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":10,"kind":"xml"}]'::jsonb,
   'm24idem-deny01')$$,
 'P0001','permission denied','dono sem fiscal.deliver nao publica');

-- Com a permissao concedida: publicacao valida.
insert into public.erp_role_permissions (tenant_id,role_id,permission_id)
 values ('9a000000-0000-4000-8000-000000000001','9e000000-0000-4000-8000-000000000001',
         (select id from public.erp_permissions where key='fiscal.deliver'));
select ok(public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-09-01',
  jsonb_build_array(
   jsonb_build_object('file_name','nfe-001.xml','storage_path','9a000000-0000-4000-8000-000000000001/2026-09/nfe-001.xml',
                      'content_hash',md5('a')||md5('b'),'byte_size',100,'kind','xml'),
   jsonb_build_object('file_name','danfe-001.pdf','storage_path','9a000000-0000-4000-8000-000000000001/2026-09/danfe-001.pdf',
                      'content_hash',md5('c')||md5('d'),'byte_size',200,'kind','danfe')),
  'm24idem-pub001') is not null,'dono com fiscal.deliver publica o pacote');
select ok(public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-09-01',
  jsonb_build_array(jsonb_build_object('file_name','nfe-001.xml','storage_path','9a000000-0000-4000-8000-000000000001/2026-09/nfe-001.xml',
                      'content_hash',md5('a')||md5('b'),'byte_size',100,'kind','xml')),
  'm24idem-pub001') = (select id from public.erp_accountant_packages
                       where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
  'mesma chave devolve o mesmo pacote (idempotente)');

-- Guardas de entrada.
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-09-01','[]'::jsonb,'m24idem-empty1')$$,
 'P0001','invalid files','lista de arquivos vazia recusada');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2027-01-01',
 '[]'::jsonb,'m24idem-futur1')$$,'P0001','invalid competencia','competencia futura recusada');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-08-01',
 '[{"file_name":"a.xml","storage_path":"outro-tenant/2026-10/a.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":10,"kind":"xml"}]'::jsonb,
 'm24idem-path01')$$,'P0001','invalid storage path','caminho fora do prefixo do tenant recusado');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-08-01',
 '[{"file_name":"a.xml","storage_path":"9a000000-0000-4000-8000-000000000001/2026-08/sub/a.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":10,"kind":"xml"}]'::jsonb,
 'm24idem-nest01')$$,'P0001','nested storage path','subpasta recusada');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-08-01',
 '[{"file_name":"a.xml","storage_path":"9a000000-0000-4000-8000-000000000001/2026-08/b.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":10,"kind":"xml"}]'::jsonb,
 'm24idem-mism01')$$,'P0001','file name mismatch','nome divergente do caminho recusado');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-08-01',
 '[{"file_name":"a.xml","storage_path":"9a000000-0000-4000-8000-000000000001/2026-08/a.xml","content_hash":"xyz","byte_size":10,"kind":"xml"}]'::jsonb,
 'm24idem-hash01')$$,'P0001','invalid content hash','hash fora do formato SHA-256 recusado');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-08-01',
 '[{"file_name":"a.xml","storage_path":"9a000000-0000-4000-8000-000000000001/2026-08/a.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":10,"kind":"danfe"}]'::jsonb,
 'm24idem-kind01')$$,'P0001','kind and extension mismatch','kind danfe em .xml recusado');
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-08-01',
 '[{"file_name":"a.xml","storage_path":"9a000000-0000-4000-8000-000000000001/2026-08/a.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":0,"kind":"xml"}]'::jsonb,
 'm24idem-size01')$$,'P0001','invalid byte size','byte_size 0 recusado');

-- Manifesto canonico: ordem de chegada nao muda o hash (B ja tem fiscal.deliver).
select set_config('request.jwt.claims','{"sub":"9b000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','9b000000-0000-4000-8000-000000000002',true);
select ok(public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000002','2026-09-01',
  jsonb_build_array(
   jsonb_build_object('file_name','danfe-001.pdf','storage_path','9a000000-0000-4000-8000-000000000002/2026-09/danfe-001.pdf',
                      'content_hash',md5('c')||md5('d'),'byte_size',200,'kind','danfe'),
   jsonb_build_object('file_name','nfe-001.xml','storage_path','9a000000-0000-4000-8000-000000000002/2026-09/nfe-001.xml',
                      'content_hash',md5('a')||md5('b'),'byte_size',100,'kind','xml')),
  'm24idem-pubB01') is not null,'dono B publica (ordem invertida nos arquivos)');
-- B recebeu os mesmos dois arquivos com a ordem INVERTIDA no array: o hash precisa bater
-- com o manifesto ordenado calculado aqui (prova de que a ordem de chegada nao importa).
select is((select content_hash from public.erp_accountant_packages
           where tenant_id='9a000000-0000-4000-8000-000000000002' and competencia='2026-09-01'),
 (select encode(extensions.digest(string_agg(l,E'\n' order by l) || E'\n','sha256'),'hex')
  from unnest(array[ md5('c')||md5('d')||' '||'9a000000-0000-4000-8000-000000000002/2026-09/danfe-001.pdf',
                     md5('a')||md5('b')||' '||'9a000000-0000-4000-8000-000000000002/2026-09/nfe-001.xml' ]) as t(l)),
 'manifesto canonico: SHA-256 ordenado por servidor, nao pela ordem enviada');
select set_config('request.jwt.claims','{"sub":"9b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','9b000000-0000-4000-8000-000000000001',true);
select throws_ok($$select public.erp_publish_accountant_package('9a000000-0000-4000-8000-000000000001','2026-09-01',
 '[{"file_name":"nfe-001.xml","storage_path":"9a000000-0000-4000-8000-000000000001/2026-09/nfe-001.xml","content_hash":"0000000000000000000000000000000000000000000000000000000000000000","byte_size":10,"kind":"xml"}]'::jsonb,
 'm24idem-dup001')$$,'P0001','competencia already published','competencia ja publicada recusada');

-- Leitura do contador: dono nao usa a RPC; contador usa e tudo passa pelo log.
select set_config('request.jwt.claims','{"sub":"9b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','9b000000-0000-4000-8000-000000000001',true);
select throws_ok($$select count(*) from public.erp_list_accountant_packages(null,10)$$,
 'P0001','permission denied','dono sem papel contador nao chama a RPC de listagem');
select set_config('request.jwt.claims','{"sub":"9c000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','9c000000-0000-4000-8000-000000000001',true);
select ok((select count(*) from public.erp_list_accountant_packages(null,10))=2,'contador lista todos os pacotes cross-tenant');
select ok(exists(select 1 from public.logs_access where user_id='9c000000-0000-4000-8000-000000000001'
 and rota='rpc:erp_list_accountant_packages'),'listagem do contador gera log quebra-vidro');
set local role authenticated;
select is((select count(*) from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001'),0::bigint,
 'contador nao le pacotes alheios por select direto (so via RPC auditada)');
set local role postgres;

-- Recibo e anulacao.
select ok(public.erp_ack_accountant_package('9a000000-0000-4000-8000-000000000001',
  (select id from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
  'Recebido em conferencia','m24idem-ack001') is not null,'contador confirma o recebimento (recibo)');
select is((select status from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
 'acknowledged','pacote fica acknowledged apos o recibo');
select throws_ok($$select public.erp_ack_accountant_package('9a000000-0000-4000-8000-000000000001',
  (select id from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
  'de novo','m24idem-ack002')$$,'P0001','already acknowledged','segundo recibo recusado');
select throws_ok($$select public.erp_void_accountant_package('9a000000-0000-4000-8000-000000000001',
  (select id from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
  'contador quer anular','m24idem-void01')$$,'P0001','permission denied','contador sem fiscal.deliver nao anula');
select public.erp_log_accountant_download('9a000000-0000-4000-8000-000000000001',
 (select id from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),2);
select ok(exists(select 1 from public.logs_access where user_id='9c000000-0000-4000-8000-000000000001'
 and rota='rpc:erp_log_accountant_download:files=2'),'download do contador gera log com a contagem');
select set_config('request.jwt.claims','{"sub":"9b000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select set_config('request.jwt.claim.sub','9b000000-0000-4000-8000-000000000001',true);
select public.erp_void_accountant_package('9a000000-0000-4000-8000-000000000001',
 (select id from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
 'pacote republicado no mes seguinte','m24idem-void02');
select is((select status from public.erp_accountant_packages where tenant_id='9a000000-0000-4000-8000-000000000001' and competencia='2026-09-01'),
 'void','dono anula o pacote apos confirmacao');
select is((select count(*) from public.erp_accountant_delivery_events where event_type='voided'),1::bigint,
 'evento voided registrado');

select * from finish();
rollback;
