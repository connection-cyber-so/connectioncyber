begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;
select plan(7);

select has_function('public', 'erp_accept_pending_memberships_v1', 'RPC de aceite de convite existe');

select throws_ok(
  $$select public.erp_accept_pending_memberships_v1()$$,
  'P0001', 'authentication required',
  'sem auth.uid() (nenhuma sessão), a função recusa'
);

insert into public.tenants (id, nome, slug, vertical, ativo)
values
  ('70000000-0000-4000-8000-000000000001', 'M18-G22 Tenant A', 'm18g22-test-a', 'varejo', true),
  ('70000000-0000-4000-8000-000000000002', 'M18-G22 Tenant B', 'm18g22-test-b', 'varejo', true);

insert into auth.users (
  id, aud, role, email, encrypted_password, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('70000000-0000-4000-8000-000000000011', 'authenticated', 'authenticated', 'm18g22-a@example.invalid', '',
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()),
  ('70000000-0000-4000-8000-000000000012', 'authenticated', 'authenticated', 'm18g22-b@example.invalid', '',
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now());

insert into public.erp_tenant_memberships (id, tenant_id, user_id, status, is_default)
values
  -- usuario A: uma membership invited (tenant A) e uma ja active (tenant B, nao deve mudar)
  ('70000000-0000-4000-8000-000000000021', '70000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000011', 'invited', true),
  ('70000000-0000-4000-8000-000000000022', '70000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000011', 'active', false),
  -- usuario B: uma membership invited (tenant B) - prova de isolamento entre usuarios
  ('70000000-0000-4000-8000-000000000023', '70000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000012', 'invited', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000011', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claims', '{"sub":"70000000-0000-4000-8000-000000000011","role":"authenticated"}', true);

select is(
  (select array_agg(id order by id) from public.erp_accept_pending_memberships_v1() as t(id)),
  array['70000000-0000-4000-8000-000000000021'::uuid],
  'ativa só a própria membership invited, retorna o id dela'
);

select is(
  (select status from public.erp_tenant_memberships where id = '70000000-0000-4000-8000-000000000021'),
  'active', 'membership do usuário A virou active de verdade'
);

select is(
  (select count(*) from public.erp_accept_pending_memberships_v1()),
  0::bigint,
  'chamar de novo é seguro — nenhuma membership invited sobrando, zero linhas, sem erro'
);

-- RLS de erp_tenant_memberships só deixa o usuário A ver as próprias linhas -
-- troca pra postgres (bypassa RLS) só pra poder observar a linha do usuário B.
set local role postgres;
select is(
  (select status from public.erp_tenant_memberships where id = '70000000-0000-4000-8000-000000000023'),
  'invited', 'membership invited do usuário B não foi tocada (isolamento entre usuários)'
);

select is(
  (select status from public.erp_tenant_memberships where id = '70000000-0000-4000-8000-000000000022'),
  'active', 'membership que já era active (outro tenant) permanece intocada'
);

select*from finish();rollback;
