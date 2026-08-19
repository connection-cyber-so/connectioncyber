-- ConnectionCyber — M04-G1 — testes pgTAP de identidade, RBAC e MFA
-- Executar somente em banco local descartável, com todas as migrations.
-- Fixtures e ledger são revertidos integralmente ao final.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;

select plan(49);

select has_table('public', 'erp_identity_provisioning_runs', 'ledger de runs existe');
select has_table('public', 'erp_identity_provisioning_steps', 'ledger de passos existe');
select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'users'
      and column_name = 'tenant_id' and is_nullable = 'YES'
  ),
  'users.tenant_id é ponte legada nullable'
);
select has_column('public', 'erp_roles', 'requires_mfa', 'role declara exigência MFA');
select has_column('public', 'erp_roles', 'sensitivity', 'role declara sensibilidade');
select has_column('public', 'erp_tenant_memberships', 'invited_at', 'membership registra convite');
select has_column('public', 'erp_tenant_memberships', 'activated_at', 'membership registra ativação');
select has_column('public', 'erp_tenant_memberships', 'suspended_at', 'membership registra suspensão');
select has_column('public', 'erp_tenant_memberships', 'revoked_at', 'membership registra revogação');
select has_column('public', 'erp_tenant_memberships', 'invitation_expires_at', 'convite possui expiração');

select ok(
  (
    select count(*) = 2 and bool_and(c.relrowsecurity)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('erp_identity_provisioning_runs', 'erp_identity_provisioning_steps')
  ),
  'RLS está habilitada nos dois ledgers'
);
select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in ('erp_identity_provisioning_runs', 'erp_identity_provisioning_steps')
      and grantee = 'anon'
  ),
  'anon não possui privilégio no provisionamento'
);
select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in ('erp_identity_provisioning_runs', 'erp_identity_provisioning_steps')
      and grantee = 'authenticated'
  ),
  'authenticated não possui privilégio no provisionamento'
);
select ok(
  (
    select count(distinct privilege_type) = 7
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'erp_identity_provisioning_runs'
      and grantee = 'service_role'
      and privilege_type in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')
  ),
  'service_role controla o ledger de runs'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'users'
      and policyname = 'users_select_self' and roles = array['authenticated']::name[]
  ),
  'policy de leitura do profile é exclusiva de authenticated'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'users'
      and policyname = 'users_update_self_profile' and roles = array['authenticated']::name[]
  ),
  'policy de atualização do profile é exclusiva de authenticated'
);
select ok(
  not has_table_privilege('authenticated', 'public.users', 'INSERT')
  and not has_table_privilege('authenticated', 'public.users', 'DELETE'),
  'authenticated não cria nem remove profiles'
);
select ok(
  has_column_privilege('authenticated', 'public.users', 'nome', 'UPDATE')
  and has_column_privilege('authenticated', 'public.users', 'idioma_preferido', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.users', 'tenant_id', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.users', 'ativo', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.users', 'email', 'UPDATE'),
  'autoedição limita-se a nome e idioma'
);
select ok(
  (select array_to_string(proconfig, ',') = 'search_path=""'
   from pg_proc where oid = 'public.handle_new_user()'::regprocedure),
  'handle_new_user usa search_path vazio'
);
select ok(
  (select array_to_string(proconfig, ',') = 'search_path=""'
   from pg_proc where oid = 'public.custom_access_token_hook(jsonb)'::regprocedure),
  'hook usa search_path vazio'
);
select ok(
  (select array_to_string(proconfig, ',') = 'search_path=""'
   from pg_proc where oid = 'public.current_tenant_id()'::regprocedure),
  'helper legado usa search_path vazio'
);
select has_function('erp_security', 'current_aal', array[]::text[], 'helper AAL existe');
select has_function(
  'erp_security', 'has_permission_at_aal', array['uuid','text','text'],
  'helper de permissão + AAL existe'
);
select ok(
  has_function_privilege('authenticated', 'erp_security.current_aal()', 'EXECUTE'),
  'authenticated pode consultar AAL normalizado'
);
select ok(
  has_function_privilege(
    'authenticated', 'erp_security.has_permission_at_aal(uuid,text,text)', 'EXECUTE'
  ),
  'authenticated pode avaliar autorização sensível'
);
select is(
  (select count(*) from public.erp_permissions
   where key in ('identities.read','identities.manage','roles.assign','mfa.read','mfa.enforce')),
  5::bigint,
  'cinco permissões M04 foram adicionadas'
);

insert into public.tenants (id, nome, slug, vertical, ativo)
values
  ('12000000-0000-4000-8000-000000000001', 'M04 Tenant A', 'm04-a', 'varejo', true),
  ('12000000-0000-4000-8000-000000000002', 'M04 Tenant B', 'm04-b', 'oficina', true);

insert into auth.users (
  id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values (
  '22000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
  'M04-OWNER@Example.Invalid', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Owner M04","tenant_id":"12000000-0000-4000-8000-000000000002"}'::jsonb,
  now(), now()
);

select is(
  (select tenant_id from public.users where id = '22000000-0000-4000-8000-000000000001'),
  null::uuid,
  'trigger ignora tenant_id controlado pelo usuário'
);
select is(
  (select email from public.users where id = '22000000-0000-4000-8000-000000000001'),
  'm04-owner@example.invalid',
  'trigger normaliza e-mail do profile'
);

select is(
  public.custom_access_token_hook(
    '{"user_id":"22000000-0000-4000-8000-000000000001","claims":{"aal":"aal1","app_metadata":{"tenant_id":"12000000-0000-4000-8000-000000000002","marker":"keep"}}}'::jsonb
  ) #>> '{claims,app_metadata,tenant_id}',
  null::text,
  'hook remove tenant_id legado do JWT'
);
select is(
  public.custom_access_token_hook(
    '{"user_id":"22000000-0000-4000-8000-000000000001","claims":{"aal":"aal1","app_metadata":{"tenant_id":"12000000-0000-4000-8000-000000000002","marker":"keep"}}}'::jsonb
  ) #>> '{claims,app_metadata,marker}',
  'keep',
  'hook preserva claims não relacionadas'
);

select throws_ok(
  $$insert into public.erp_identity_provisioning_runs (
      idempotency_key, manifest_sha256, schema_version, environment,
      execution_mode, summary
    ) values (
      'm04:secret:0001', repeat('a', 64), 1, 'staging', 'dry_run',
      '{"password":"never"}'::jsonb
    )$$,
  '23514', null,
  'ledger recusa segredo no summary'
);

insert into public.erp_identity_provisioning_runs (
  id, idempotency_key, manifest_sha256, schema_version, environment,
  execution_mode, subject_count
) values (
  '52000000-0000-4000-8000-000000000001', 'm04:dry-run:0001', repeat('b', 64),
  1, 'staging', 'dry_run', 1
);

select throws_ok(
  $$insert into public.erp_identity_provisioning_runs (
      idempotency_key, manifest_sha256, schema_version, environment, execution_mode
    ) values ('m04:dry-run:0001', repeat('c', 64), 1, 'staging', 'dry_run')$$,
  '23505', null,
  'idempotency_key impede run duplicada'
);
select throws_ok(
  $$insert into public.erp_identity_provisioning_runs (
      idempotency_key, manifest_sha256, schema_version, environment,
      execution_mode, status
    ) values ('m04:completed:0001', repeat('d', 64), 1, 'staging', 'dry_run', 'completed')$$,
  '23514', null,
  'run concluída exige finished_at'
);
select throws_ok(
  $$insert into public.erp_identity_provisioning_steps (
      run_id, step_key, subject_key, action, detail
    ) values (
      '52000000-0000-4000-8000-000000000001', 'p01.validate', 'p01_owner_a',
      'validate_identity', '{"access_token":"never"}'::jsonb
    )$$,
  '23514', null,
  'ledger recusa segredo no detail do passo'
);
select throws_ok(
  $$insert into public.erp_tenant_memberships (
      tenant_id, user_id, status, invited_at, invitation_expires_at
    ) values (
      '12000000-0000-4000-8000-000000000002',
      '22000000-0000-4000-8000-000000000001', 'invited', now(), now() - interval '1 minute'
    )$$,
  '23514', null,
  'convite não pode expirar antes de ser emitido'
);
select throws_ok(
  $$insert into public.erp_roles (tenant_id, key, name, requires_mfa, sensitivity)
    values (
      '12000000-0000-4000-8000-000000000002',
      'admin', 'Admin inseguro', false, 'privileged'
    )$$,
  '23514', null,
  'papel privilegiado não pode existir sem MFA'
);

insert into public.erp_tenant_memberships (
  id, tenant_id, user_id, status, is_default, activated_at
) values (
  '32000000-0000-4000-8000-000000000001',
  '12000000-0000-4000-8000-000000000001',
  '22000000-0000-4000-8000-000000000001', 'active', true, now()
);
insert into public.erp_roles (
  id, tenant_id, key, name, requires_mfa, sensitivity
) values (
  '42000000-0000-4000-8000-000000000001',
  '12000000-0000-4000-8000-000000000001',
  'owner', 'Proprietário', true, 'privileged'
);
insert into public.erp_role_permissions (tenant_id, role_id, permission_id)
select
  '12000000-0000-4000-8000-000000000001',
  '42000000-0000-4000-8000-000000000001', id
from public.erp_permissions where key = 'identities.manage';
insert into public.erp_membership_roles (tenant_id, membership_id, role_id)
values (
  '12000000-0000-4000-8000-000000000001',
  '32000000-0000-4000-8000-000000000001',
  '42000000-0000-4000-8000-000000000001'
);

select ok(
  (select requires_mfa and sensitivity = 'privileged'
   from public.erp_roles where id = '42000000-0000-4000-8000-000000000001'),
  'owner é papel privilegiado com MFA'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '22000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);

select is(erp_security.current_aal(), 'aal1', 'sessão AAL1 é reconhecida');
select ok(
  erp_security.has_permission_at_aal(
    '12000000-0000-4000-8000-000000000001', 'identities.manage', 'aal1'
  ),
  'permissão comum aceita AAL1'
);
select ok(
  not erp_security.has_permission_at_aal(
    '12000000-0000-4000-8000-000000000001', 'identities.manage', 'aal2'
  ),
  'ação sensível recusa AAL1'
);
select ok(
  not erp_security.has_permission_at_aal(
    '12000000-0000-4000-8000-000000000002', 'identities.manage', 'aal1'
  ),
  'permissão do tenant A não autoriza tenant B'
);
select is((select count(*) from public.users), 1::bigint, 'usuário lê somente o próprio profile');
select lives_ok(
  $$update public.users set nome = 'Owner atualizado' where id = auth.uid()$$,
  'usuário atualiza campo de apresentação'
);
select throws_ok(
  $$update public.users set tenant_id = '12000000-0000-4000-8000-000000000002' where id = auth.uid()$$,
  '42501', null,
  'usuário não altera tenant legado'
);
select throws_ok(
  $$select count(*) from public.erp_identity_provisioning_runs$$,
  '42501', null,
  'cliente não consulta ledger server-only'
);
select throws_ok(
  $$insert into public.erp_identity_provisioning_runs (
      idempotency_key, manifest_sha256, schema_version, environment, execution_mode
    ) values ('m04:client:0001', repeat('e', 64), 1, 'staging', 'dry_run')$$,
  '42501', null,
  'cliente não grava ledger server-only'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"22000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal2"}',
  true
);
select is(erp_security.current_aal(), 'aal2', 'sessão AAL2 é reconhecida');
select ok(
  erp_security.has_permission_at_aal(
    '12000000-0000-4000-8000-000000000001', 'identities.manage', 'aal2'
  ),
  'ação sensível aceita permissão explícita em AAL2'
);
select ok(
  not erp_security.has_permission_at_aal(
    '12000000-0000-4000-8000-000000000001', 'identities.manage', 'aal3'
  ),
  'AAL desconhecido é deny-by-default'
);

set local role postgres;
select * from finish();
rollback;
