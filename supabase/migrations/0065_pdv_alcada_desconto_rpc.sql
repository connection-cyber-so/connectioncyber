-- 0065 · PDV · alçada de desconto: aprovador e solicitante validados por RPC
-- Fecha a lacuna da 0063: o insert direto em erp_discount_authorizations deixa de existir.
-- Toda autorização passa por public.erp_authorize_discount(...).
-- Regras da RPC:
--   1) sessão autenticada (auth.uid()) e com sales.discount no tenant = aprovador;
--   2) solicitante = membro ativo do tenant (membership ativa e vigente, usuário e tenant ativos);
--   3) aprovador diferente do solicitante;
--   4) desconto acima do limite configurado (pdv.discount.auto_limit_percent, padrão 5);
--      abaixo do limite não há autorização a registrar.
-- Fora deste gate: PIN/MFA do aprovador (decisão futura), alçada de sangria e fechamento.

drop policy if exists erp_discount_authorizations_insert on public.erp_discount_authorizations;
revoke insert on public.erp_discount_authorizations from authenticated;

create or replace function public.erp_authorize_discount(
  p_tenant_id uuid,
  p_establishment_id uuid,
  p_sale_id uuid,
  p_requested_by uuid,
  p_discount_amount numeric,
  p_discount_percent numeric,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approver uuid := (select auth.uid());
  v_limit numeric;
  v_id uuid;
begin
  if v_approver is null then
    raise exception 'erp_authorize_discount: sessao autenticada obrigatoria'
      using errcode = '42501';
  end if;

  if not (select erp_security.has_permission(p_tenant_id, 'sales.discount')) then
    raise exception 'erp_authorize_discount: aprovador sem permissao sales.discount'
      using errcode = '42501';
  end if;

  if p_requested_by is null or p_requested_by = v_approver then
    raise exception 'erp_authorize_discount: solicitante invalido ou igual ao aprovador'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
      from public.erp_tenant_memberships m
      join public.users u on u.id = m.user_id
      join public.tenants t on t.id = m.tenant_id
     where m.tenant_id = p_tenant_id
       and m.user_id = p_requested_by
       and m.status = 'active'
       and u.ativo
       and t.ativo
       and (m.starts_at is null or m.starts_at <= now())
       and (m.ends_at is null or m.ends_at > now())
  ) then
    raise exception 'erp_authorize_discount: solicitante nao e membro ativo do tenant'
      using errcode = '42501';
  end if;

  select coalesce((s.value ->> 'percent')::numeric, 5) into v_limit
    from public.erp_tenant_settings s
   where s.tenant_id = p_tenant_id
     and s.key = 'pdv.discount.auto_limit_percent'
     and s.establishment_id is null;
  v_limit := coalesce(v_limit, 5);

  if p_discount_percent <= v_limit then
    raise exception 'erp_authorize_discount: desconto dentro do limite automatico configurado, sem alcada'
      using errcode = '23514';
  end if;

  insert into public.erp_discount_authorizations
    (tenant_id, establishment_id, sale_id, requested_by, approved_by,
     discount_amount, discount_percent, limit_percent, reason)
  values
    (p_tenant_id, p_establishment_id, p_sale_id, p_requested_by, v_approver,
     p_discount_amount, p_discount_percent, v_limit, p_reason)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text) from public, anon;
grant execute on function public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text) to authenticated;
