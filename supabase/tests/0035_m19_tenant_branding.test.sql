begin;

set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;

select plan(16);

select has_table('public', 'erp_tenant_branding', 'tabela de branding por tenant existe');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.erp_tenant_branding'::regclass),
  'RLS habilitada em erp_tenant_branding'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'erp_tenant_branding' and grantee = 'anon'
  ),
  'anon não possui privilégios em erp_tenant_branding'
);

select ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'erp_tenant_branding'
      and grantee = 'authenticated' and privilege_type = 'DELETE'
  ),
  'authenticated não pode apagar branding — só inserir/atualizar sob RLS'
);

-- Dois tenants sintéticos: A concede branding.manage ao seu owner, B não concede a ninguém.
insert into public.tenants (id, nome, slug, vertical, ativo)
values
  ('60000000-0000-4000-8000-000000000001', 'M19 Tenant A', 'm19-test-a', 'varejo', true),
  ('60000000-0000-4000-8000-000000000002', 'M19 Tenant B', 'm19-test-b', 'varejo', true);

insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('60000000-0000-4000-8000-000000000011', 'authenticated', 'authenticated', 'm19-owner-a@example.invalid', '',
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()),
  ('60000000-0000-4000-8000-000000000012', 'authenticated', 'authenticated', 'm19-viewer-b@example.invalid', '',
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now());

insert into public.erp_tenant_memberships (id, tenant_id, user_id, status, is_default)
values
  ('60000000-0000-4000-8000-000000000021', '60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000011', 'active', true),
  ('60000000-0000-4000-8000-000000000022', '60000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000012', 'active', true);

-- 'owner'/'admin' exigem requires_mfa+sensitivity='privileged' (0018,
-- erp_roles_privileged_mfa_required) — irrelevante pro RLS de branding em si,
-- mas obrigatório pra inserir a fixture.
insert into public.erp_roles (id, tenant_id, key, name, requires_mfa, sensitivity)
values
  ('60000000-0000-4000-8000-000000000031', '60000000-0000-4000-8000-000000000001', 'owner', 'Owner A', true, 'privileged'),
  ('60000000-0000-4000-8000-000000000032', '60000000-0000-4000-8000-000000000002', 'viewer', 'Viewer B', false, 'standard');

insert into public.erp_membership_roles (tenant_id, membership_id, role_id)
values
  ('60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000021', '60000000-0000-4000-8000-000000000031'),
  ('60000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000022', '60000000-0000-4000-8000-000000000032');

-- Só o owner do tenant A recebe branding.manage — viewer do tenant B fica sem.
insert into public.erp_role_permissions (tenant_id, role_id, permission_id)
select '60000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000031', id
from public.erp_permissions where key = 'branding.manage';

-- ---- sessão do owner do tenant A ----
set local role authenticated;
select set_config('request.jwt.claim.sub', '60000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000011","role":"authenticated"}', true);

select lives_ok(
  $$select public.erp_set_tenant_branding('60000000-0000-4000-8000-000000000001', '#F6851F', 'https://cdn.example.invalid/logo.png')$$,
  'owner com branding.manage grava a identidade visual do próprio tenant'
);

select is(
  (select primary_color from public.erp_tenant_branding where tenant_id = '60000000-0000-4000-8000-000000000001'),
  '#f6851f', 'cor gravada em minúsculas, normalizada pela função'
);

select throws_ok(
  $$select public.erp_set_tenant_branding('60000000-0000-4000-8000-000000000001', 'laranja', null)$$,
  'P0001', 'invalid primary_color',
  'cor fora do formato hexadecimal é recusada'
);

select throws_ok(
  $$select public.erp_set_tenant_branding('60000000-0000-4000-8000-000000000001', null, 'http://cdn.example.invalid/logo.png')$$,
  'P0001', 'invalid logo_url',
  'logo sem https é recusado'
);

select throws_ok(
  $$select public.erp_set_tenant_branding('60000000-0000-4000-8000-000000000002', '#111111', null)$$,
  '42501', null,
  'owner do tenant A não grava branding do tenant B (RLS insert bloqueia)'
);

select is(
  (select count(*) from public.erp_tenant_branding),
  1::bigint,
  'owner do tenant A só enxerga a própria linha de branding (RLS select)'
);

-- ---- sessão do viewer do tenant B (sem branding.manage) ----
set local role authenticated;
select set_config('request.jwt.claim.sub', '60000000-0000-4000-8000-000000000012', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"60000000-0000-4000-8000-000000000012","role":"authenticated"}', true);

select throws_ok(
  $$select public.erp_set_tenant_branding('60000000-0000-4000-8000-000000000002', '#222222', null)$$,
  '42501', null,
  'viewer sem branding.manage não grava a identidade visual do próprio tenant'
);

select is(
  (select count(*) from public.erp_tenant_branding),
  0::bigint,
  'viewer do tenant B não enxerga a linha de branding do tenant A (RLS select)'
);

set local role postgres;

select is(
  (select count(*) from public.erp_tenant_branding),
  1::bigint,
  'postgres (owner de teste) enxerga a linha real gravada'
);

select is(
  (select updated_by from public.erp_tenant_branding where tenant_id = '60000000-0000-4000-8000-000000000001'),
  '60000000-0000-4000-8000-000000000011'::uuid,
  'updated_by grava quem realmente fez a escrita (auth.uid() da sessão), não um valor arbitrário'
);

select ok(
  exists (select 1 from public.erp_permissions where key = 'branding.manage' and category = 'foundation'),
  'permissão branding.manage está no catálogo'
);

select ok(
  exists (
    select 1 from public.erp_role_permissions rp
    join public.erp_roles r on r.id = rp.role_id
    where r.tenant_id = '60000000-0000-4000-8000-000000000001' and r.key = 'owner'
      and rp.permission_id = (select id from public.erp_permissions where key = 'branding.manage')
  ),
  'owner do tenant A tem branding.manage vinculado (setup do teste, espelha o backfill da migration)'
);

select*from finish();rollback;
