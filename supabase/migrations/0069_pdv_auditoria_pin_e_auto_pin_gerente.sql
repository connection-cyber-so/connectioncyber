-- 0069 · PDV · auditoria do cadastro de PIN e controle do PIN do próprio gerente
-- Decisões (07/11/2026):
--   - Cadastro de PIN exige trilha de auditoria (append-only).
--   - Gerente pode cadastrar PIN para si mesmo somente se o tenant ligar
--     'pdv.alcada.allow_self_pin' (configurável; padrão desligado).
--   - Aprovação de solicitação do próprio usuário continua proibida (solicitante <> aprovador, 0063/0065/0066).
-- Mudanças:
--   1) tabela erp_approver_pin_audit (sem PIN, sem hash; só quem, para quem, quando, se foi autoatribuição);
--   2) trigger que bloqueia UPDATE e DELETE na auditoria;
--   3) seed de 'pdv.alcada.allow_self_pin' = {"enabled": false} nos tenants;
--   4) erp_manager_set_approver_pin: checa a chave e grava a auditoria a cada cadastro.

-- 1) Auditoria
create table public.erp_approver_pin_audit (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  target_user_id uuid not null references public.users (id),
  changed_by uuid not null references public.users (id),
  action text not null check (action in ('set')),
  is_self boolean not null,
  created_at timestamptz not null default now(),
  constraint erp_approver_pin_audit_self_check check (is_self = (target_user_id = changed_by))
);

create index erp_approver_pin_audit_tenant_target_idx
  on public.erp_approver_pin_audit (tenant_id, target_user_id, created_at desc);

alter table public.erp_approver_pin_audit enable row level security;
revoke all on public.erp_approver_pin_audit from anon, authenticated;
grant select on public.erp_approver_pin_audit to authenticated;

create policy erp_approver_pin_audit_select
  on public.erp_approver_pin_audit
  for select
  to authenticated
  using (
    (select erp_security.has_permission(tenant_id, 'memberships.manage'))
    or (select public.is_platform_staff())
  );

-- 2) Imutabilidade
create or replace function public.erp_approver_pin_audit_block_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'erp_approver_pin_audit: registro de auditoria é imutável' using errcode = '42501';
end;
$$;

create trigger erp_approver_pin_audit_immutable
  before update or delete on public.erp_approver_pin_audit
  for each row execute function public.erp_approver_pin_audit_block_change();

-- 3) Configuração: auto-PIN do gerente, desligado por padrão
insert into public.erp_tenant_settings (tenant_id, establishment_id, key, value, sensitivity, schema_version)
select t.id, null, 'pdv.alcada.allow_self_pin', '{"enabled": false}'::jsonb, 'internal', 1
  from public.tenants t
 where not exists (
   select 1 from public.erp_tenant_settings s
    where s.tenant_id = t.id and s.key = 'pdv.alcada.allow_self_pin' and s.establishment_id is null
 );

-- 4) Cadastro de PIN pelo gerente, com configuração e auditoria
create or replace function public.erp_manager_set_approver_pin(
  p_tenant_id uuid,
  p_target_user_id uuid,
  p_new_pin text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_manager uuid := (select auth.uid());
  v_is_self boolean;
  v_self_allowed boolean;
begin
  if v_manager is null then
    raise exception 'erp_manager_set_approver_pin: sessao autenticada obrigatoria' using errcode = '42501';
  end if;

  if not ((select erp_security.has_permission(p_tenant_id, 'memberships.manage')) or (select public.is_platform_staff())) then
    raise exception 'erp_manager_set_approver_pin: gerente sem permissao memberships.manage' using errcode = '42501';
  end if;

  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,6}$' then
    raise exception 'erp_manager_set_approver_pin: PIN deve ter de 4 a 6 digitos' using errcode = '22023';
  end if;

  if not exists (
    select 1
      from public.erp_tenant_memberships m
      join public.users u on u.id = m.user_id
      join public.tenants t on t.id = m.tenant_id
     where m.tenant_id = p_tenant_id
       and m.user_id = p_target_user_id
       and m.status = 'active'
       and u.ativo
       and t.ativo
       and (m.starts_at is null or m.starts_at <= now())
       and (m.ends_at is null or m.ends_at > now())
  ) then
    raise exception 'erp_manager_set_approver_pin: usuario alvo nao e membro ativo do tenant' using errcode = '42501';
  end if;

  if not exists (
    select 1
      from public.erp_tenant_memberships m
      join public.erp_membership_roles mr on mr.tenant_id = m.tenant_id and mr.membership_id = m.id
      join public.erp_role_permissions rp on rp.tenant_id = mr.tenant_id and rp.role_id = mr.role_id
      join public.erp_permissions pe on pe.id = rp.permission_id
     where m.tenant_id = p_tenant_id
       and m.user_id = p_target_user_id
       and pe.key in ('sales.discount', 'cash.adjust', 'cash.close')
  ) then
    raise exception 'erp_manager_set_approver_pin: usuario alvo sem permissao de alcada' using errcode = '23514';
  end if;

  v_is_self := (p_target_user_id = v_manager);

  if v_is_self then
    select coalesce((s.value ->> 'enabled')::boolean, false) into v_self_allowed
      from public.erp_tenant_settings s
     where s.tenant_id = p_tenant_id and s.key = 'pdv.alcada.allow_self_pin' and s.establishment_id is null;
    if not coalesce(v_self_allowed, false) then
      raise exception 'erp_manager_set_approver_pin: PIN do proprio gerente desligado pela configuracao do tenant' using errcode = '42501';
    end if;
  end if;

  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until, updated_at)
  values (p_tenant_id, p_target_user_id, extensions.crypt(p_new_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();

  insert into public.erp_approver_pin_audit (tenant_id, target_user_id, changed_by, action, is_self)
  values (p_tenant_id, p_target_user_id, v_manager, 'set', v_is_self);

  return 'ok';
end;
$$;

revoke all on function public.erp_manager_set_approver_pin(uuid, uuid, text) from public, anon;
grant execute on function public.erp_manager_set_approver_pin(uuid, uuid, text) to authenticated;
