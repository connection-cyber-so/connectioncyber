begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(4);

select ok(to_regclass('public.erp_role_permissions') is not null,'tabela erp_role_permissions existe');
select ok(to_regclass('public.erp_roles') is not null,'tabela erp_roles existe');

-- invariante geral (não só de hoje): nenhuma concessão pro papel 'owner' aponta pra
-- permissão inativa — a migration 0041 filtra por p.active, igual ao provisionamento
-- original (0034) já fazia pra tenant novo.
select ok(not exists(
  select 1 from public.erp_role_permissions rp
  join public.erp_roles r on r.tenant_id=rp.tenant_id and r.id=rp.role_id
  join public.erp_permissions p on p.id=rp.permission_id
  where r.key='owner' and not p.active
),'nenhuma concessão do papel owner aponta pra permissão inativa');

-- as duas permissões novas que motivaram este gate (M20-G1 e M21-G1) existem no catálogo
-- e são exatamente as que passam a ser retroativamente concedidas a tenants antigos.
select is((select count(*)::int from public.erp_permissions where key in ('fiscal.item.read','fiscal.item.manage','establishments.manage') and active),3,'as três permissões que motivaram o backfill existem e estão ativas');

select * from finish();
rollback;
