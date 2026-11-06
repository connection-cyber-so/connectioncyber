begin; set local role postgres; create extension if not exists pgtap with schema extensions; set local search_path=public,extensions,pgtap; select plan(6);
-- Executa os mesmos inserts da migration dentro desta transação e reverte tudo no fim.
insert into public.tenants (id, nome, slug, vertical, dominio, ativo)
values ('00000000-0000-0000-0000-000000000001', 'Nuvem de Papel', 'nuvemdepapel', 'papelaria', null, true);
insert into public.tenant_domains (hostname, tenant_id, status)
values ('nuvemdepapel.com.br', '00000000-0000-0000-0000-000000000001', 'pendente');
insert into public.erp_tenant_capabilities (tenant_id, capability_key, status, evidence_hash) values
  ('00000000-0000-0000-0000-000000000001'::uuid, 'sales.pos', 'active', '8241d4cc3f21a79ad598432dc1ce23c8aa6a62c81ad35429043e41b2be2f991f'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'sales.orders', 'active', '4bad53912209d54020222ac006da0f09fea9e33c5e5bfdd79666a0d5f63e0bc0'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'core.parties', 'active', '54e818e1b0c679ac6481c213f4b64ed0058566ffe20ceb313b2c7b9aa44f12a8'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'core.catalog', 'active', '8b2ac834a85457e28cd8f5c127bad28b10a40c08081ea7b692a4d4d4979737c2'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'core.pricing', 'active', '660d4d4bd1ef1f0993490ed604967838643bbf212607c61c8de46fae17620854'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'procurement', 'active', '16ffca657a6510df3d4a4bb5387ac1883d00885593bc16afdfc4e40cbc82128a'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'inventory.stock', 'active', 'f2e76b78206115ea05e06607944b3674539821597ff29c0e4dc0f11116ee18d7'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'finance', 'active', '3e15985ae3710a2d0c86bf5fd6e61b9f717c899f38a5d1c2971a99c9cc6aec48'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'migration', 'active', '996a3e4f5894299bc9f9ebc5e101aec4fa1e4f879dd51fe2255a7de8f9398754'),
  ('00000000-0000-0000-0000-000000000001'::uuid, 'fiscal', 'disabled', 'b4476056091d26d5c59c3a7ace18c70fdb005ca018150e99db4230837d783e46');
select is((select count(*)::int from public.tenants where slug = 'nuvemdepapel'), 1, 'tenant criado uma vez');
select is((select vertical from public.tenants where slug = 'nuvemdepapel'), 'papelaria', 'vertical papelaria');
select is((select status from public.tenant_domains where hostname = 'nuvemdepapel.com.br'), 'pendente', 'dominio entra pendente');
select is(public.resolve_tenant_by_host('nuvemdepapel.com.br'), null, 'dominio pendente nao resolve');
select is((select count(*)::int from public.erp_tenant_capabilities where tenant_id = '00000000-0000-0000-0000-000000000001' and status = 'active'), 9, '9 capacidades ativas');
select is((select status from public.erp_tenant_capabilities where tenant_id = '00000000-0000-0000-0000-000000000001' and capability_key = 'fiscal'), 'disabled', 'fiscal disabled');
select * from finish();
rollback;
