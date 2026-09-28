begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;
select plan(14);

-- fixtures: dois tenants sintéticos, um staff (bypass via user_roles/admin, mesmo
-- mecanismo de is_platform_staff() de 0002_multi_tenant.sql) e um usuário comum sem
-- nenhuma permissão nem staff — prova o caminho de negação, não só o de sucesso.
insert into public.tenants (id, nome, slug, vertical, ativo) values
  ('71000000-0000-4000-8000-000000000001', 'M21-G1 Synthetic A', 'm21-g1-synthetic-a', 'teste', true),
  ('71000000-0000-4000-8000-000000000002', 'M21-G1 Synthetic B', 'm21-g1-synthetic-b', 'teste', true);

insert into auth.users (id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at) values
  ('71000000-0000-4000-8000-000000000011', 'authenticated', 'authenticated', 'm21g1-staff@example.invalid', '', '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()),
  ('71000000-0000-4000-8000-000000000012', 'authenticated', 'authenticated', 'm21g1-nobody@example.invalid', '', '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now());

-- auth.users acima já disparou o trigger de auto-provisionamento de public.users
-- (0003_bpo_patterns_auto_provisioning_and_hook.sql) — não inserir de novo, só linkar o papel.
insert into public.user_roles(user_id,role_id) values ('71000000-0000-4000-8000-000000000011',(select id from public.roles where nome='admin'));

insert into public.erp_units(tenant_id,code,name) values ('71000000-0000-4000-8000-000000000001','UN','Unidade');
insert into public.erp_parties(id,tenant_id,kind,legal_name) values ('71000000-0000-4000-8000-000000000021','71000000-0000-4000-8000-000000000001','person','Pessoa Sintetica M21-G1');
insert into public.erp_catalog_items(id,tenant_id,kind,code,name,base_unit_id) values (
  '71000000-0000-4000-8000-000000000031','71000000-0000-4000-8000-000000000001','product','M21-G1-ITEM','Item Sintetico M21-G1',
  (select id from public.erp_units where tenant_id='71000000-0000-4000-8000-000000000001' and code='UN')
);
insert into public.erp_establishments(id,tenant_id,code,trade_name) values ('71000000-0000-4000-8000-000000000041','71000000-0000-4000-8000-000000000001','MATRIZ','Estabelecimento Sintetico M21-G1');

-- 1) sem sessão nenhuma (auth.uid() null): recusa antes de qualquer coisa
select throws_ok(
  $$select public.erp_command_add_party_document_v1('71000000-0000-4000-8000-000000000001'::uuid,'doc-noauth-001','0000000000000000000000000000000000000000000000000000000000000000'::text,'{}'::jsonb)$$,
  '42501','authentication required',
  'sem auth.uid(), comando recusa antes de checar payload'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000012',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000012","role":"authenticated"}',true);

-- 2) autenticado, mas sem permissão e sem ser staff: nega mesmo com payload válido
select throws_ok(
  format($$select public.erp_command_add_party_document_v1('71000000-0000-4000-8000-000000000001'::uuid,'doc-denied-001',%L,%L::jsonb)$$,
    encode(extensions.digest(convert_to(jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-1')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-1')::text
  ),
  '42501','command access denied',
  'autenticado sem permissão nem staff é recusado (não é bypass geral pra qualquer authenticated)'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-4000-8000-000000000011',true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims','{"sub":"71000000-0000-4000-8000-000000000011","role":"authenticated"}',true);

-- 3) staff: caminho feliz de party.document.add
select is(
  (select public.erp_command_add_party_document_v1('71000000-0000-4000-8000-000000000001'::uuid,'doc-happy-001',
    encode(extensions.digest(convert_to(jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-12.345.678')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-12.345.678')
  )->>'status'),
  'created',
  'staff cria documento com sucesso'
);

-- 4) replay do mesmo request_id + mesmo payload: idempotente, não duplica. O retorno de
--    um replay é o MESMO result_json gravado na primeira vez (sem marcador "replayed" —
--    esse marcador só existe internamente em erp_claim_command_v1, nunca sai pra fora),
--    então a prova de idempotência é: chamada de novo não estoura erro e não duplica linha.
select is(
  (select public.erp_command_add_party_document_v1('71000000-0000-4000-8000-000000000001'::uuid,'doc-happy-001',
    encode(extensions.digest(convert_to(jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-12.345.678')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-12.345.678')
  )->>'status'),
  'created',
  'mesmo request_id + mesmo payload é replay silencioso (mesmo resultado, sem erro)'
);
select is((select count(*)::int from public.erp_party_documents where party_id='71000000-0000-4000-8000-000000000021'),1,'replay não criou segundo documento');

-- 5) mesmo request_id, payload divergente: conflito de idempotência
select throws_ok(
  $$select public.erp_command_add_party_document_v1('71000000-0000-4000-8000-000000000001'::uuid,'doc-happy-001',
    encode(extensions.digest(convert_to(jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','cpf','number','111.444.777-35')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','cpf','number','111.444.777-35')
  )$$,
  '23505','idempotency conflict',
  'mesmo request_id com payload diferente é conflito de idempotência'
);

-- 6) isolamento cross-tenant: staff manda p_tenant_id=B mas partyId é da A — falha por
--    "não encontrado", nunca escreve num tenant usando id de outro
select throws_ok(
  $$select public.erp_command_add_party_document_v1('71000000-0000-4000-8000-000000000002'::uuid,'doc-crosstenant-001',
    encode(extensions.digest(convert_to(jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-1')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('partyId','71000000-0000-4000-8000-000000000021','type','rg','number','MG-1')
  )$$,
  '22023','party not found',
  'party de outro tenant não é encontrado — isolamento cross-tenant'
);

-- 7) establishment.vertical.set: caminho feliz (vertical real, seedada no M20-G2)
select is(
  (select public.erp_command_set_establishment_vertical_v1('71000000-0000-4000-8000-000000000001'::uuid,'estab-vert-001',
    encode(extensions.digest(convert_to(jsonb_build_object('establishmentId','71000000-0000-4000-8000-000000000041','verticalCode','moda')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('establishmentId','71000000-0000-4000-8000-000000000041','verticalCode','moda')
  )->>'status'),
  'saved',
  'staff atribui vertical real ao estabelecimento'
);
select is((select vertical_code from public.erp_establishments where id='71000000-0000-4000-8000-000000000041'),'moda','vertical gravada de verdade na tabela');

-- 8) vertical inexistente: recusa
select throws_ok(
  $$select public.erp_command_set_establishment_vertical_v1('71000000-0000-4000-8000-000000000001'::uuid,'estab-vert-002',
    encode(extensions.digest(convert_to(jsonb_build_object('establishmentId','71000000-0000-4000-8000-000000000041','verticalCode','nao_existe')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('establishmentId','71000000-0000-4000-8000-000000000041','verticalCode','nao_existe')
  )$$,
  '22023','vertical not found',
  'código de vertical inexistente é recusado'
);

-- 9) isolamento cross-tenant no estabelecimento: tenant B não enxerga estabelecimento da A
select throws_ok(
  $$select public.erp_command_set_establishment_vertical_v1('71000000-0000-4000-8000-000000000002'::uuid,'estab-vert-003',
    encode(extensions.digest(convert_to(jsonb_build_object('establishmentId','71000000-0000-4000-8000-000000000041','verticalCode','moda')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('establishmentId','71000000-0000-4000-8000-000000000041','verticalCode','moda')
  )$$,
  '22023','establishment not found',
  'estabelecimento de outro tenant não é encontrado — isolamento cross-tenant'
);

-- 10) catalog.item.fiscal.set: caminho feliz + upsert (chama de novo com NCM diferente)
select is(
  (select public.erp_command_set_item_fiscal_data_v1('71000000-0000-4000-8000-000000000001'::uuid,'item-fiscal-001',
    encode(extensions.digest(convert_to(jsonb_build_object('itemId','71000000-0000-4000-8000-000000000031','ncm','61091000','taxCodeKind','CST','taxCode','00')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('itemId','71000000-0000-4000-8000-000000000031','ncm','61091000','taxCodeKind','CST','taxCode','00')
  )->>'status'),
  'saved',
  'staff grava dado fiscal (regime Normal, CST)'
);
select is(
  (select public.erp_command_set_item_fiscal_data_v1('71000000-0000-4000-8000-000000000001'::uuid,'item-fiscal-002',
    encode(extensions.digest(convert_to(jsonb_build_object('itemId','71000000-0000-4000-8000-000000000031','ncm','61099000','taxCodeKind','CST','taxCode','00')::text,'UTF8'),'sha256'),'hex'),
    jsonb_build_object('itemId','71000000-0000-4000-8000-000000000031','ncm','61099000','taxCodeKind','CST','taxCode','00')
  )->>'status'),
  'saved',
  'segunda chamada atualiza (upsert), não duplica'
);
select is((select count(*)::int from public.erp_item_fiscal_data where item_id='71000000-0000-4000-8000-000000000031'),1,'upsert manteve uma única linha fiscal por item');

select * from finish();
rollback;
