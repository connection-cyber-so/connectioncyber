begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(5);

-- fixtures: um tenant sintético "antigo" com o papel owner já criado, mas com uma lacuna
-- deliberada (falta uma permissão ativa) — simula exatamente o caso real da Mania de Modas
-- (provisionada antes de fiscal.item.manage/establishments.manage existirem). Não dá pra
-- testar contra o efeito histórico real de 0041 (rodou antes destes fixtures existirem),
-- então este teste roda a MESMA lógica da migration de novo, isolada, pra provar que o
-- comportamento é o correto e é idempotente.
insert into public.tenants(id,nome,slug,vertical) values ('72000000-0000-4000-8000-000000000001','M21-G2 Synthetic','m21-g2-synthetic','teste');
insert into public.erp_roles(id,tenant_id,key,name,is_system,requires_mfa,sensitivity) values ('72000000-0000-4000-8000-000000000011','72000000-0000-4000-8000-000000000001','owner','Proprietário',true,true,'privileged');
insert into public.erp_roles(id,tenant_id,key,name,is_system) values ('72000000-0000-4000-8000-000000000012','72000000-0000-4000-8000-000000000001','vendedor','Vendedor',false);
-- concede só UMA permissão de propósito, deixando as demais ativas de fora (a lacuna).
insert into public.erp_role_permissions(tenant_id,role_id,permission_id) values (
  '72000000-0000-4000-8000-000000000001','72000000-0000-4000-8000-000000000011',
  (select id from public.erp_permissions where key='parties.manage')
);

select is((select count(*)::int from public.erp_role_permissions where tenant_id='72000000-0000-4000-8000-000000000001'),1,'antes do backfill, owner sintético só tem uma permissão (lacuna deliberada)');

-- roda a mesma lógica de 0041
insert into public.erp_role_permissions(tenant_id,role_id,permission_id)
select r.tenant_id, r.id, p.id
from public.erp_roles r
cross join public.erp_permissions p
where r.key = 'owner' and r.is_system and p.active
on conflict (tenant_id,role_id,permission_id) do nothing;

select is(
  (select count(*)::int from public.erp_role_permissions where tenant_id='72000000-0000-4000-8000-000000000001' and role_id='72000000-0000-4000-8000-000000000011'),
  (select count(*)::int from public.erp_permissions where active),
  'depois do backfill, owner sintético tem todas as permissões ativas, lacuna fechada'
);

select is(
  (select count(*)::int from public.erp_role_permissions where role_id='72000000-0000-4000-8000-000000000012'),
  0,
  'papel não-owner (vendedor) não é tocado pelo backfill'
);

-- rodar de novo é seguro (idempotente) — não duplica nem estoura erro
insert into public.erp_role_permissions(tenant_id,role_id,permission_id)
select r.tenant_id, r.id, p.id
from public.erp_roles r
cross join public.erp_permissions p
where r.key = 'owner' and r.is_system and p.active
on conflict (tenant_id,role_id,permission_id) do nothing;

select is(
  (select count(*)::int from public.erp_role_permissions where tenant_id='72000000-0000-4000-8000-000000000001' and role_id='72000000-0000-4000-8000-000000000011'),
  (select count(*)::int from public.erp_permissions where active),
  'rodar o backfill de novo é idempotente, não duplica'
);

-- desativa uma permissão sintética e confirma que backfill nunca concede permissão inativa
update public.erp_permissions set active=false where key='parties.manage';
delete from public.erp_role_permissions where tenant_id='72000000-0000-4000-8000-000000000001' and permission_id=(select id from public.erp_permissions where key='parties.manage');
insert into public.erp_role_permissions(tenant_id,role_id,permission_id)
select r.tenant_id, r.id, p.id
from public.erp_roles r
cross join public.erp_permissions p
where r.key = 'owner' and r.is_system and p.active
on conflict (tenant_id,role_id,permission_id) do nothing;
select is(
  (select count(*)::int from public.erp_role_permissions where tenant_id='72000000-0000-4000-8000-000000000001' and permission_id=(select id from public.erp_permissions where key='parties.manage')),
  0,
  'permissão desativada não é (re)concedida pelo backfill'
);
update public.erp_permissions set active=true where key='parties.manage';

select * from finish();
rollback;
