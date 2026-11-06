begin; set local role postgres; create extension if not exists pgtap with schema extensions; set local search_path=public,extensions,pgtap; select plan(16);

-- Fixtures sintéticas (nunca dado real). Dois tenants para testar isolamento.
insert into public.tenants (id, nome, slug, vertical, dominio) values
  ('a0530000-0000-4000-8000-000000000001', '0053 Tenant A', 'm53-tenant-a', 'synthetic-test', 'a.m53.invalid'),
  ('a0530000-0000-4000-8000-000000000002', '0053 Tenant B', 'm53-tenant-b', 'synthetic-test', 'b.m53.invalid');

-- 1-5: estrutura e privilégios.
select has_table('public', 'tenant_domains', 'tabela tenant_domains existe');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.tenant_domains'::regclass),
  'RLS ligada em tenant_domains'
);
select ok(not has_table_privilege('anon', 'public.tenant_domains', 'select'), 'anon sem select');
select ok(not has_table_privilege('authenticated', 'public.tenant_domains', 'select'), 'authenticated sem select');
select has_function('public', 'resolve_tenant_by_host', array['text'], 'funcao de resolucao existe');

-- 6-7: inserções válidas.
select lives_ok(
  $$ insert into public.tenant_domains (hostname, tenant_id, status, verificado_em)
     values ('loja-a.m53.invalid', 'a0530000-0000-4000-8000-000000000001', 'ativo', now()) $$,
  'dominio ativo do tenant A aceito'
);
select lives_ok(
  $$ insert into public.tenant_domains (hostname, tenant_id, status)
     values ('pend-a.m53.invalid', 'a0530000-0000-4000-8000-000000000001', 'pendente') $$,
  'dominio pendente do tenant A aceito'
);

-- 8-11: resolução.
select is(public.resolve_tenant_by_host('loja-a.m53.invalid'), 'a0530000-0000-4000-8000-000000000001'::uuid, 'dominio ativo resolve para o tenant A');
select is(public.resolve_tenant_by_host('pend-a.m53.invalid'), null, 'dominio pendente nao resolve');
select is(public.resolve_tenant_by_host('LOJA-A.M53.INVALID'), 'a0530000-0000-4000-8000-000000000001'::uuid, 'resolucao ignora caixa');
select is(public.resolve_tenant_by_host('desconhecido.m53.invalid'), null, 'dominio desconhecido nao resolve');

-- 12-14: restrições negativas.
select throws_ok(
  $$ insert into public.tenant_domains (hostname, tenant_id, status, verificado_em)
     values ('loja-a.m53.invalid', 'a0530000-0000-4000-8000-000000000002', 'ativo', now()) $$,
  '23505', null, 'hostname duplicado bloqueado entre tenants'
);
select throws_ok(
  $$ insert into public.tenant_domains (hostname, tenant_id, status)
     values ('Loja-X.m53.invalid', 'a0530000-0000-4000-8000-000000000001', 'pendente') $$,
  '23514', null, 'hostname com maiusculas bloqueado'
);
select throws_ok(
  $$ insert into public.tenant_domains (hostname, tenant_id, status)
     values ('sem-data.m53.invalid', 'a0530000-0000-4000-8000-000000000001', 'verificado') $$,
  '23514', null, 'status verificado exige verificado_em'
);

-- 15-16: isolamento por tenant suspenso.
select lives_ok(
  $$ insert into public.tenant_domains (hostname, tenant_id, status, verificado_em)
     values ('loja-b.m53.invalid', 'a0530000-0000-4000-8000-000000000002', 'ativo', now()) $$,
  'dominio ativo do tenant B aceito'
);
update public.tenants set ativo = false where id = 'a0530000-0000-4000-8000-000000000002';
select is(public.resolve_tenant_by_host('loja-b.m53.invalid'), null, 'tenant suspenso nao resolve');

select * from finish();
rollback;
