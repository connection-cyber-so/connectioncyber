-- ConnectionCyber — M02 — testes pgTAP da fundação ERP
-- Executar em banco local descartável, depois de aplicar todas as migrations:
--   supabase test db supabase/tests/0016_erp_foundation.test.sql
-- Todo dado sintético fica dentro desta transação e é descartado no rollback.

begin;

-- A CLI remota conecta como cli_login_postgres (membro de postgres), mas esse
-- login não herda USAGE do schema extensions. O papel elevado existe somente
-- dentro desta transação de teste e é revertido junto com todos os fixtures.
set local role postgres;

create extension if not exists pgtap with schema extensions;
-- O Supabase local instala pgTAP em extensions; o executor remoto pode
-- materializá-lo em pgtap durante a transação. Ambos precisam ser portáveis.
set local search_path = public, extensions, pgtap;

select plan(38);

select has_schema('erp_security', 'schema privado erp_security existe');
select has_table('public', 'erp_tenant_memberships', 'memberships existe');
select has_table('public', 'erp_roles', 'roles ERP existe');
select has_table('public', 'erp_permissions', 'permissions ERP existe');
select has_table('public', 'erp_role_permissions', 'role_permissions existe');
select has_table('public', 'erp_membership_roles', 'membership_roles existe');
select has_table('public', 'erp_establishments', 'establishments existe');
select has_table('public', 'erp_capability_catalog', 'catálogo de capacidades existe');
select has_table('public', 'erp_tenant_capabilities', 'capacidades por tenant existe');
select has_table('public', 'erp_segment_profiles', 'perfis de segmento existe');
select has_table('public', 'erp_segment_profile_capabilities', 'mapa perfil-capacidade existe');
select has_table('public', 'erp_tenant_segment_profiles', 'perfis por tenant existe');
select has_table('public', 'erp_tenant_settings', 'configurações por tenant existe');
select has_table('public', 'erp_number_sequences', 'sequências existe');
select has_table('public', 'erp_audit_events', 'auditoria existe');

select ok(
  (
    select count(*) = 14 and bool_and(c.relrowsecurity)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = any (array[
        'erp_tenant_memberships', 'erp_roles', 'erp_permissions',
        'erp_role_permissions', 'erp_membership_roles', 'erp_establishments',
        'erp_capability_catalog', 'erp_tenant_capabilities',
        'erp_segment_profiles', 'erp_segment_profile_capabilities',
        'erp_tenant_segment_profiles', 'erp_tenant_settings',
        'erp_number_sequences', 'erp_audit_events'
      ])
  ),
  'RLS está habilitada nas 14 tabelas'
);

select is((select count(*) from public.erp_capability_catalog), 23::bigint,
  'catálogo possui 23 capacidades globais');
select is((select count(*) from public.erp_segment_profiles), 5::bigint,
  'catálogo possui cinco perfis multissegmento');

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name like 'erp_%'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'TRIGGER')
  ),
  'authenticated não possui DML nas tabelas ERP'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name like 'erp_%'
      and grantee = 'anon'
  ),
  'anon não possui privilégios nas tabelas ERP'
);

select ok(
  has_function_privilege('authenticated', 'erp_security.is_tenant_member(uuid)', 'EXECUTE')
  and has_function_privilege('authenticated', 'erp_security.has_permission(uuid,text)', 'EXECUTE'),
  'authenticated executa somente helpers de autorização necessários'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'erp_security.next_number(uuid,text,uuid,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.erp_next_number(uuid,text,uuid,date)',
    'EXECUTE'
  ),
  'authenticated não pode consumir numeração diretamente'
);

-- Dois tenants e dois usuários sintéticos para provar isolamento.
insert into public.tenants (id, nome, slug, vertical, ativo)
values
  ('10000000-0000-4000-8000-000000000001', 'M02 Tenant A', 'm02-test-a', 'varejo', true),
  ('10000000-0000-4000-8000-000000000002', 'M02 Tenant B', 'm02-test-b', 'oficina', true);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '20000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
    'm02-a@example.invalid', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nome":"M02 User A","tenant_id":"10000000-0000-4000-8000-000000000001"}'::jsonb,
    now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
    'm02-b@example.invalid', '', now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nome":"M02 User B","tenant_id":"10000000-0000-4000-8000-000000000002"}'::jsonb,
    now(), now()
  );

insert into public.erp_tenant_memberships (id, tenant_id, user_id, status, is_default)
values
  ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'active', true),
  ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'active', true);

insert into public.erp_roles (id, tenant_id, key, name)
values
  ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'operator', 'Operador A'),
  ('40000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'operator', 'Operador B');

insert into public.erp_membership_roles (tenant_id, membership_id, role_id)
values
  ('10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002');

insert into public.erp_establishments (id, tenant_id, code, kind, trade_name)
values
  ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'MATRIZ', 'headquarters', 'Matriz A'),
  ('50000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'MATRIZ', 'headquarters', 'Matriz B');

insert into public.erp_tenant_capabilities (tenant_id, capability_key, status)
values
  ('10000000-0000-4000-8000-000000000001', 'core.organization', 'active'),
  ('10000000-0000-4000-8000-000000000002', 'core.organization', 'active');

insert into public.erp_tenant_segment_profiles (tenant_id, profile_key, is_primary)
values
  ('10000000-0000-4000-8000-000000000001', 'retail_general', true),
  ('10000000-0000-4000-8000-000000000002', 'workshop', true);

insert into public.erp_tenant_settings (tenant_id, establishment_id, key, value)
values
  ('10000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', 'sales.allow_negative_stock', 'false'::jsonb),
  ('10000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000002', 'sales.allow_negative_stock', 'false'::jsonb);

insert into public.erp_number_sequences (
  tenant_id, establishment_id, sequence_key, prefix, padding
)
values (
  '10000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000001',
  'sales.order', 'A-', 4
);

insert into public.erp_audit_events (
  tenant_id, establishment_id, actor_user_id, actor_membership_id,
  action, entity_type, entity_id
)
values (
  '10000000-0000-4000-8000-000000000001',
  '50000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'foundation.tested', 'test_fixture', 'A'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);

select is((select count(*) from public.erp_tenant_memberships), 1::bigint,
  'usuário A vê somente sua membership');
select is((select count(*) from public.erp_establishments), 1::bigint,
  'usuário A vê somente estabelecimentos do tenant A');
select is((select count(*) from public.erp_tenant_capabilities), 1::bigint,
  'usuário A vê somente capacidades do tenant A');
select is((select count(*) from public.erp_tenant_settings), 1::bigint,
  'usuário A vê somente configurações do tenant A');
select is((select count(*) from public.erp_tenant_segment_profiles), 1::bigint,
  'usuário A vê somente perfis do tenant A');
select is((select count(*) from public.erp_membership_roles), 1::bigint,
  'usuário A vê somente seus vínculos de papel');
select is((select count(*) from public.erp_audit_events), 1::bigint,
  'ator A vê seu próprio evento de auditoria');

select throws_ok(
  $$insert into public.erp_establishments (tenant_id, code, trade_name)
    values ('10000000-0000-4000-8000-000000000001', 'FILIAL', 'Tentativa')$$,
  '42501', null,
  'authenticated não pode gravar diretamente na fundação'
);

set local role postgres;

select throws_ok(
  $$insert into public.erp_membership_roles (tenant_id, membership_id, role_id)
    values (
      '10000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000002'
    )$$,
  '23503', null,
  'FK composta bloqueia papel de outro tenant'
);

select throws_ok(
  $$insert into public.erp_tenant_settings (tenant_id, establishment_id, key, value)
    values (
      '10000000-0000-4000-8000-000000000001',
      '50000000-0000-4000-8000-000000000002',
      'cross.tenant', 'true'::jsonb
    )$$,
  '23503', null,
  'FK composta bloqueia estabelecimento de outro tenant'
);

select throws_ok(
  $$insert into public.erp_tenant_settings (tenant_id, key, value)
    values (
      '10000000-0000-4000-8000-000000000001',
      'fiscal.certificate_password', '"proibido"'::jsonb
    )$$,
  '23514', null,
  'configuração comum recusa chave com indício de segredo'
);

select throws_ok(
  $$insert into public.erp_audit_events (
      tenant_id, actor_user_id, actor_membership_id, action, entity_type
    ) values (
      '10000000-0000-4000-8000-000000000001',
      '20000000-0000-4000-8000-000000000002',
      '30000000-0000-4000-8000-000000000001',
      'foundation.denied', 'test_fixture'
    )$$,
  '23503', null,
  'auditoria recusa ator diferente do usuário da membership'
);

select results_eq(
  $$select public.erp_next_number(
      '10000000-0000-4000-8000-000000000001',
      'sales.order',
      '50000000-0000-4000-8000-000000000001',
      date '2026-08-18'
    )$$,
  array['A-0001'::text],
  'primeiro número é alocado corretamente'
);

select results_eq(
  $$select public.erp_next_number(
      '10000000-0000-4000-8000-000000000001',
      'sales.order',
      '50000000-0000-4000-8000-000000000001',
      date '2026-08-18'
    )$$,
  array['A-0002'::text],
  'segunda alocação é monotônica'
);

select throws_ok(
  $$update public.erp_audit_events set outcome = 'error' where entity_id = 'A'$$,
  '55000', 'ERP_AUDIT_EVENTS_APPEND_ONLY',
  'auditoria não aceita update'
);

select throws_ok(
  $$delete from public.erp_audit_events where entity_id = 'A'$$,
  '55000', 'ERP_AUDIT_EVENTS_APPEND_ONLY',
  'auditoria não aceita delete'
);

select * from finish();
rollback;
