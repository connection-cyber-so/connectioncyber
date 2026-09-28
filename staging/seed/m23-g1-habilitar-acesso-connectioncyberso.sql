-- M23-G1 — Habilita o acesso da conta connectioncyberso@gmail.com ao portal /academia
-- Problema: a conta existe em Auth (uid e2b88e26-94b9-4ead-8955-9d22f98d269b) mas não possui
--           nenhuma erp_tenant_memberships ativa => decidePortalAccess = 'no-membership'
--           => /academia redireciona para /sem-empresa.
-- Uso:      supabase db query --linked -f staging/seed/m23-g1-habilitar-acesso-connectioncyberso.sql
-- Idempotente: reexecutar não duplica nada (on conflict).

begin;

do $$
declare
  v_user_id uuid := 'e2b88e26-94b9-4ead-8955-9d22f98d269b';
  v_tenant_id uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3'; -- Mania de Modas
  v_email text;
  v_tenant_ativo boolean;
  v_role_id uuid;
  v_academy_perms int;
begin
  select u.email into v_email from auth.users u where u.id = v_user_id;
  if v_email is distinct from 'connectioncyberso@gmail.com' then
    raise exception 'PRECONDITION: usuario % nao encontrado/no Auth (email=%)', v_user_id, coalesce(v_email, 'nulo');
  end if;

  select t.ativo into v_tenant_ativo from public.tenants t where t.id = v_tenant_id;
  if v_tenant_ativo is distinct from true then
    raise exception 'PRECONDITION: tenant % ativo=% (esperado true)', v_tenant_id, coalesce(v_tenant_ativo::text, 'nao existe');
  end if;

  select r.id into v_role_id from public.erp_roles r where r.tenant_id = v_tenant_id and r.key = 'owner';
  if v_role_id is null then
    raise exception 'PRECONDITION: papel owner ausente no tenant %', v_tenant_id;
  end if;

  select count(*) into v_academy_perms
    from public.erp_role_permissions rp
    join public.erp_permissions p on p.id = rp.permission_id
   where rp.role_id = v_role_id and p.key in ('academy.read', 'academy.manage');
  if v_academy_perms < 2 then
    raise exception 'PRECONDITION: owner sem academy.read/academy.manage (achou %)', v_academy_perms;
  end if;
end $$;

insert into public.erp_tenant_memberships (id, tenant_id, user_id, status, is_default, activated_at, updated_at)
select gen_random_uuid(), '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3', 'e2b88e26-94b9-4ead-8955-9d22f98d269b', 'active', true, now(), now()
on conflict (tenant_id, user_id)
do update set status = 'active',
              is_default = true,
              activated_at = now(),
              suspended_at = null,
              revoked_at = null,
              updated_at = now();

insert into public.erp_membership_roles (tenant_id, membership_id, role_id)
select m.tenant_id, m.id, r.id
  from public.erp_tenant_memberships m
  join public.erp_roles r on r.tenant_id = m.tenant_id and r.key = 'owner'
 where m.user_id = 'e2b88e26-94b9-4ead-8955-9d22f98d269b'
   and m.tenant_id = '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3'
on conflict do nothing;

-- Verificacao (assemelha-se ao decidePortalAccess do portal)
select
  m.status,
  m.is_default,
  t.nome as tenant,
  (m.starts_at is null or m.starts_at <= now()) and (m.ends_at is null or m.ends_at > now()) as vigente,
  (select count(*) from public.erp_membership_roles mr where mr.membership_id = m.id) as papeis,
  exists (
    select 1
      from public.erp_membership_roles mr
      join public.erp_role_permissions rp on rp.role_id = mr.role_id
      join public.erp_permissions p on p.id = rp.permission_id
     where mr.membership_id = m.id and p.key = 'academy.read'
  ) as academy_read,
  exists (
    select 1
      from public.erp_membership_roles mr
      join public.erp_role_permissions rp on rp.role_id = mr.role_id
      join public.erp_permissions p on p.id = rp.permission_id
     where mr.membership_id = m.id and p.key = 'academy.manage'
  ) as academy_manage,
  (select count(*) from public.erp_tenant_memberships x where x.user_id = m.user_id and x.status = 'active') as active_memberships_total
  from public.erp_tenant_memberships m
  join public.tenants t on t.id = m.tenant_id
 where m.user_id = 'e2b88e26-94b9-4ead-8955-9d22f98d269b';

commit;

