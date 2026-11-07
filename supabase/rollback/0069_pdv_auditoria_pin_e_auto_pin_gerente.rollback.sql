-- ROLLBACK 0069 · PDV · auditoria do PIN e auto-PIN do gerente
-- ATENÇÃO: apaga a trilha de auditoria (erp_approver_pin_audit). Só para laboratório.
-- Em staging/produção, preferir forward-fix. Os PINs cadastrados não são alterados.
-- Corpo de erp_manager_set_approver_pin copiado de supabase/migrations/0068_pdv_pin_cadastrado_pelo_gerente.sql.

begin;

drop trigger if exists erp_approver_pin_audit_immutable on public.erp_approver_pin_audit;
drop function if exists public.erp_approver_pin_audit_block_change();
drop table if exists public.erp_approver_pin_audit;

delete from public.erp_tenant_settings where key = 'pdv.alcada.allow_self_pin' and establishment_id is null;

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

  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until, updated_at)
  values (p_tenant_id, p_target_user_id, extensions.crypt(p_new_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();

  return 'ok';
end;
$$;

revoke all on function public.erp_manager_set_approver_pin(uuid, uuid, text) from public, anon;
grant execute on function public.erp_manager_set_approver_pin(uuid, uuid, text) to authenticated;

commit;
