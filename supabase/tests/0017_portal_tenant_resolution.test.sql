-- ConnectionCyber — M03 — testes pgTAP de domínio e isolamento do portal
-- Executar somente em banco local descartável depois das migrations 0001–0017.
-- Fixtures são revertidas ao final.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;

select plan(35);

select has_table('public', 'erp_tenant_domains', 'tabela canônica de domínios existe');
select ok(
  to_regprocedure('erp_security.normalize_hostname(text)') is not null,
  'normalizador privado existe'
);
select ok(
  to_regprocedure('public.portal_resolve_host(text)') is not null,
  'resolver público mínimo existe'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.erp_tenant_domains'::regclass),
  'RLS está habilitada na tabela de domínios'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.erp_tenant_domains'::regclass
      and conname = 'erp_tenant_domains_hostname_unique'
  ),
  'hostname possui unicidade canônica'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.erp_tenant_domains'::regclass
      and conname = 'erp_tenant_domains_active_verified'
  ),
  'domínio ativo exige verificação'
);
select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.erp_tenant_domains'::regclass
      and conname = 'erp_tenant_domains_primary_active'
  ),
  'domínio primário precisa estar ativo'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'tenants'
      and policyname = 'tenants_select_erp_membership'
  ),
  'tenant pode ser lido por membership ERP ativa'
);
select ok(
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'erp_tenant_domains'
      and policyname = 'erp_tenant_domains_select_own_membership'
  ),
  'domínio possui policy exclusiva de membership própria'
);
select ok(
  not has_table_privilege('anon', 'public.erp_tenant_domains', 'SELECT'),
  'anon não lê a tabela de domínios'
);
select ok(
  has_table_privilege('authenticated', 'public.erp_tenant_domains', 'SELECT'),
  'authenticated pode consultar domínios sob RLS'
);
select ok(
  not has_table_privilege('authenticated', 'public.erp_tenant_domains', 'INSERT')
  and not has_table_privilege('authenticated', 'public.erp_tenant_domains', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.erp_tenant_domains', 'DELETE'),
  'authenticated não possui DML em domínios'
);
select ok(
  has_function_privilege('anon', 'public.portal_resolve_host(text)', 'EXECUTE'),
  'anon executa somente o resolver público mínimo'
);
select ok(
  has_function_privilege('authenticated', 'public.portal_resolve_host(text)', 'EXECUTE'),
  'authenticated executa o resolver'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'erp_security.normalize_hostname(text)',
    'EXECUTE'
  ),
  'authenticated não executa diretamente o helper privado'
);

insert into public.tenants (id, nome, slug, vertical, ativo)
values
  ('11000000-0000-4000-8000-000000000001', 'M03 Tenant A', 'm03-a', 'varejo', true),
  ('11000000-0000-4000-8000-000000000002', 'M03 Tenant B', 'm03-b', 'oficina', true),
  ('11000000-0000-4000-8000-000000000003', 'M03 Staff Home', 'm03-staff', 'assessoria', true);

insert into auth.users (
  id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '21000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
    'm03-a@example.invalid', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nome":"M03 User A","tenant_id":"11000000-0000-4000-8000-000000000002"}'::jsonb,
    now(), now()
  ),
  (
    '21000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
    'm03-b@example.invalid', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nome":"M03 User B","tenant_id":"11000000-0000-4000-8000-000000000002"}'::jsonb,
    now(), now()
  ),
  (
    '21000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
    'm03-staff@example.invalid', '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nome":"M03 Staff","tenant_id":"11000000-0000-4000-8000-000000000003"}'::jsonb,
    now(), now()
  );

-- A partir da 0018, metadata de signup não define tenant. Este teste do M03
-- prepara explicitamente a ponte legada para provar que ela não autoriza o portal.
update public.users profile
set tenant_id = case profile.id
  when '21000000-0000-4000-8000-000000000001'::uuid then '11000000-0000-4000-8000-000000000002'::uuid
  when '21000000-0000-4000-8000-000000000002'::uuid then '11000000-0000-4000-8000-000000000002'::uuid
  when '21000000-0000-4000-8000-000000000003'::uuid then '11000000-0000-4000-8000-000000000003'::uuid
end
where profile.id in (
  '21000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000002',
  '21000000-0000-4000-8000-000000000003'
);

insert into public.erp_tenant_memberships (id, tenant_id, user_id, status, is_default)
values
  ('31000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', '21000000-0000-4000-8000-000000000001', 'active', true),
  ('31000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000002', '21000000-0000-4000-8000-000000000002', 'active', true);

insert into public.roles (nome, descricao)
values ('admin', 'Administrador de teste M03')
on conflict (nome) do nothing;
insert into public.user_roles (user_id, role_id)
select '21000000-0000-4000-8000-000000000003', id
from public.roles where nome = 'admin';

insert into public.erp_tenant_domains (
  id, tenant_id, hostname, domain_type, status, is_primary,
  verification_method, verified_at
)
values
  ('41000000-0000-4000-8000-000000000001', '11000000-0000-4000-8000-000000000001', 'm03-a.connectioncyber.com.br', 'subdomain', 'active', true, 'dns_cname', now()),
  ('41000000-0000-4000-8000-000000000002', '11000000-0000-4000-8000-000000000001', 'alias-a.connectioncyber.com.br', 'subdomain', 'pending', false, null, null),
  ('41000000-0000-4000-8000-000000000003', '11000000-0000-4000-8000-000000000002', 'm03-b.connectioncyber.com.br', 'subdomain', 'active', true, 'dns_cname', now()),
  ('41000000-0000-4000-8000-000000000004', '11000000-0000-4000-8000-000000000002', 'pausado.example.test', 'custom', 'suspended', false, 'dns_txt', now());

select is(
  erp_security.normalize_hostname(' M03-A.ConnectionCyber.com.br. '),
  'm03-a.connectioncyber.com.br',
  'normalizador remove caixa, espaços e ponto final'
);
select is(
  erp_security.normalize_hostname('*.connectioncyber.com.br'),
  null::text,
  'normalizador recusa wildcard'
);
select is(
  erp_security.normalize_hostname('m03-a.connectioncyber.com.br:443'),
  null::text,
  'normalizador recusa porta'
);
select is(
  (select count(*) from public.portal_resolve_host('m03-a.connectioncyber.com.br')),
  1::bigint,
  'resolver encontra domínio ativo e verificado'
);
select results_eq(
  $$select tenant_slug from public.portal_resolve_host(' M03-A.ConnectionCyber.com.br. ')$$,
  array['m03-a'::text],
  'resolver usa normalização estrita sem comparação parcial'
);
select is(
  (select count(*) from public.portal_resolve_host('desconhecido.connectioncyber.com.br')),
  0::bigint,
  'resolver desconhecido retorna zero linhas'
);
select is(
  (select count(*) from public.portal_resolve_host('alias-a.connectioncyber.com.br')),
  0::bigint,
  'resolver não expõe domínio pendente'
);
select is(
  (select count(*) from public.portal_resolve_host('pausado.example.test')),
  0::bigint,
  'resolver não expõe domínio suspenso'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '21000000-0000-4000-8000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"21000000-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
select is(
  (select count(*) from public.erp_tenant_domains),
  2::bigint,
  'usuário A vê somente os dois domínios do próprio tenant ERP'
);
select is(
  (select count(*) from public.erp_tenant_domains where tenant_id = '11000000-0000-4000-8000-000000000002'),
  0::bigint,
  'usuário A não vê domínios do tenant B'
);
select ok(
  exists (select 1 from public.tenants where id = '11000000-0000-4000-8000-000000000001'),
  'usuário A lê tenant A pela membership mesmo com users.tenant_id legado apontando para B'
);
select throws_ok(
  $$insert into public.erp_tenant_domains (tenant_id, hostname)
    values ('11000000-0000-4000-8000-000000000001', 'tentativa.connectioncyber.com.br')$$,
  '42501', null,
  'authenticated não grava domínio diretamente'
);

set local role postgres;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '21000000-0000-4000-8000-000000000003',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"21000000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
select is(
  (select count(*) from public.erp_tenant_domains),
  0::bigint,
  'staff sem membership não recebe bypass na tabela de domínios'
);

set local role postgres;
select ok(
  not exists (
    select 1
    from public.erp_tenant_domains domain
    join public.erp_tenant_memberships membership
      on membership.tenant_id = domain.tenant_id
    where domain.hostname = 'm03-b.connectioncyber.com.br'
      and membership.user_id = '21000000-0000-4000-8000-000000000001'
      and membership.status = 'active'
  ),
  'host B não encontra membership ativa do usuário A'
);
select throws_ok(
  $$insert into public.erp_tenant_domains (
      tenant_id, hostname, domain_type, status, verified_at
    ) values (
      '11000000-0000-4000-8000-000000000001',
      'sem-verificacao.connectioncyber.com.br', 'subdomain', 'active', null
    )$$,
  '23514', null,
  'domínio ativo sem verificação é recusado'
);
select throws_ok(
  $$insert into public.erp_tenant_domains (tenant_id, hostname)
    values ('11000000-0000-4000-8000-000000000001', 'Maiusculo.ConnectionCyber.com.br')$$,
  '23514', null,
  'hostname não canônico é recusado no armazenamento'
);
select throws_ok(
  $$insert into public.erp_tenant_domains (tenant_id, hostname)
    values ('11000000-0000-4000-8000-000000000002', 'm03-a.connectioncyber.com.br')$$,
  '23505', null,
  'hostname não pode pertencer a dois tenants'
);
select throws_ok(
  $$insert into public.erp_tenant_domains (tenant_id, hostname, is_primary)
    values ('11000000-0000-4000-8000-000000000001', 'primario-pendente.connectioncyber.com.br', true)$$,
  '23514', null,
  'domínio pendente não pode ser primário'
);
select throws_ok(
  $$insert into public.erp_tenant_domains (
      tenant_id, hostname, status, is_primary, verification_method, verified_at
    ) values (
      '11000000-0000-4000-8000-000000000001',
      'segundo-primario.connectioncyber.com.br', 'active', true, 'dns_cname', now()
    )$$,
  '23505', null,
  'tenant possui no máximo um domínio primário ativo'
);

update public.tenants set ativo = false where id = '11000000-0000-4000-8000-000000000001';
select is(
  (select count(*) from public.portal_resolve_host('m03-a.connectioncyber.com.br')),
  0::bigint,
  'resolver não expõe domínio de tenant inativo'
);

select * from finish();
rollback;
