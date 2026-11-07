-- 0067 · PDV · PIN do aprovador para alçadas de desconto (0065) e de caixa (0066)
-- Decisões aprovadas (07/11/2026): PIN vale para caixa e desconto; 5 erros bloqueiam por 15 minutos.
-- Regras:
--   1) PIN de 4 a 6 dígitos, guardado só como hash bcrypt (extensions.crypt / gen_salt('bf')).
--   2) O aprovador define o próprio PIN; trocar exige o PIN atual.
--   3) Erro de PIN NÃO lança exceção: devolve status, para o contador de erros persistir.
--      Por isso as RPCs de autorização passam a devolver jsonb { status, authorization_id? }.
--   4) Sem PIN cadastrado, status 'pin_missing': nenhuma autorização é gravada.
-- Estados de PIN: ok | pin_invalid | pin_locked | pin_missing.

-- 1) PIN por aprovador (sem acesso direto; só por funções security definer)
create table public.erp_approver_pins (
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  pin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, user_id),
  constraint erp_approver_pins_attempts_check check (failed_attempts >= 0)
);

alter table public.erp_approver_pins enable row level security;
revoke all on public.erp_approver_pins from anon, authenticated;

-- 2) Verificação interna do PIN (conta erros e bloqueio; não lança exceção)
create or replace function public.erp_check_approver_pin(p_tenant_id uuid, p_user_id uuid, p_pin text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.erp_approver_pins%rowtype;
begin
  select * into r from public.erp_approver_pins
   where tenant_id = p_tenant_id and user_id = p_user_id
   for update;
  if not found then
    return 'pin_missing';
  end if;

  if r.locked_until is not null and r.locked_until > now() then
    return 'pin_locked';
  end if;

  if p_pin is not null and extensions.crypt(p_pin, r.pin_hash) = r.pin_hash then
    update public.erp_approver_pins
       set failed_attempts = 0, locked_until = null
     where tenant_id = p_tenant_id and user_id = p_user_id;
    return 'ok';
  end if;

  if r.failed_attempts + 1 >= 5 then
    update public.erp_approver_pins
       set failed_attempts = 0, locked_until = now() + interval '15 minutes'
     where tenant_id = p_tenant_id and user_id = p_user_id;
    return 'pin_locked';
  end if;

  update public.erp_approver_pins
     set failed_attempts = r.failed_attempts + 1
   where tenant_id = p_tenant_id and user_id = p_user_id;
  return 'pin_invalid';
end;
$$;

revoke all on function public.erp_check_approver_pin(uuid, uuid, text) from public, anon, authenticated;

-- 3) Definir ou trocar o próprio PIN
create or replace function public.erp_set_approver_pin(p_tenant_id uuid, p_new_pin text, p_current_pin text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_status text;
begin
  if v_user is null then
    raise exception 'erp_set_approver_pin: sessao autenticada obrigatoria' using errcode = '42501';
  end if;

  if p_new_pin is null or p_new_pin !~ '^[0-9]{4,6}$' then
    raise exception 'erp_set_approver_pin: PIN deve ter de 4 a 6 digitos' using errcode = '22023';
  end if;

  if not (select erp_security.has_permission(p_tenant_id, 'sales.discount')
          or erp_security.has_permission(p_tenant_id, 'cash.adjust')
          or erp_security.has_permission(p_tenant_id, 'cash.close')) then
    raise exception 'erp_set_approver_pin: usuario sem permissao de alcada' using errcode = '42501';
  end if;

  if exists (select 1 from public.erp_approver_pins where tenant_id = p_tenant_id and user_id = v_user) then
    v_status := public.erp_check_approver_pin(p_tenant_id, v_user, p_current_pin);
    if v_status <> 'ok' then
      return v_status;
    end if;
  end if;

  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until, updated_at)
  values (p_tenant_id, v_user, extensions.crypt(p_new_pin, extensions.gen_salt('bf')), 0, null, now())
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null, updated_at = now();

  return 'ok';
end;
$$;

revoke all on function public.erp_set_approver_pin(uuid, text, text) from public, anon;
grant execute on function public.erp_set_approver_pin(uuid, text, text) to authenticated;

-- 4) Alçada de desconto (0065) com PIN
drop function if exists public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text);

create or replace function public.erp_authorize_discount(
  p_tenant_id uuid,
  p_establishment_id uuid,
  p_sale_id uuid,
  p_requested_by uuid,
  p_discount_amount numeric,
  p_discount_percent numeric,
  p_reason text,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approver uuid := (select auth.uid());
  v_limit numeric;
  v_status text;
  v_id uuid;
begin
  if v_approver is null then
    raise exception 'erp_authorize_discount: sessao autenticada obrigatoria' using errcode = '42501';
  end if;

  if not (select erp_security.has_permission(p_tenant_id, 'sales.discount')) then
    raise exception 'erp_authorize_discount: aprovador sem permissao sales.discount' using errcode = '42501';
  end if;

  if p_requested_by is null or p_requested_by = v_approver then
    raise exception 'erp_authorize_discount: solicitante invalido ou igual ao aprovador' using errcode = '23514';
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
    raise exception 'erp_authorize_discount: solicitante nao e membro ativo do tenant' using errcode = '42501';
  end if;

  select coalesce((s.value ->> 'percent')::numeric, 5) into v_limit
    from public.erp_tenant_settings s
   where s.tenant_id = p_tenant_id and s.key = 'pdv.discount.auto_limit_percent' and s.establishment_id is null;
  v_limit := coalesce(v_limit, 5);

  if p_discount_percent <= v_limit then
    raise exception 'erp_authorize_discount: desconto dentro do limite automatico configurado, sem alcada' using errcode = '23514';
  end if;

  v_status := public.erp_check_approver_pin(p_tenant_id, v_approver, p_pin);
  if v_status <> 'ok' then
    return jsonb_build_object('status', v_status);
  end if;

  insert into public.erp_discount_authorizations
    (tenant_id, establishment_id, sale_id, requested_by, approved_by,
     discount_amount, discount_percent, limit_percent, reason)
  values
    (p_tenant_id, p_establishment_id, p_sale_id, p_requested_by, v_approver,
     p_discount_amount, p_discount_percent, v_limit, p_reason)
  returning id into v_id;

  return jsonb_build_object('status', 'authorized', 'authorization_id', v_id);
end;
$$;

revoke all on function public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text, text) from public, anon;
grant execute on function public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text, text) to authenticated;

-- 5) Alçada de caixa (0066) com PIN
drop function if exists public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text);

create or replace function public.erp_authorize_cash_action(
  p_tenant_id uuid,
  p_cash_session_id uuid,
  p_kind text,
  p_amount numeric,
  p_requested_by uuid,
  p_reason text,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approver uuid := (select auth.uid());
  v_perm text;
  v_status text;
  v_session_status text;
  v_expected numeric;
  v_limit numeric;
  v_amount numeric;
  v_threshold numeric;
  v_pin_status text;
  v_id uuid;
begin
  if v_approver is null then
    raise exception 'erp_authorize_cash_action: sessao autenticada obrigatoria' using errcode = '42501';
  end if;

  if p_kind not in ('withdrawal', 'close') then
    raise exception 'erp_authorize_cash_action: tipo invalido' using errcode = '22023';
  end if;

  v_perm := case when p_kind = 'withdrawal' then 'cash.adjust' else 'cash.close' end;
  if not (select erp_security.has_permission(p_tenant_id, v_perm)) then
    raise exception 'erp_authorize_cash_action: aprovador sem permissao %', v_perm using errcode = '42501';
  end if;

  if p_requested_by is null or p_requested_by = v_approver then
    raise exception 'erp_authorize_cash_action: solicitante invalido ou igual ao aprovador' using errcode = '23514';
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
    raise exception 'erp_authorize_cash_action: solicitante nao e membro ativo do tenant' using errcode = '42501';
  end if;

  select s.status into v_session_status
    from public.erp_cash_sessions s
   where s.tenant_id = p_tenant_id and s.id = p_cash_session_id;
  if not found then
    raise exception 'erp_authorize_cash_action: sessao de caixa nao encontrada' using errcode = 'P0002';
  end if;
  if v_session_status = 'closed' then
    raise exception 'erp_authorize_cash_action: sessao ja fechada' using errcode = '55000';
  end if;

  if p_kind = 'withdrawal' then
    select coalesce((s.value ->> 'amount')::numeric, 500) into v_limit
      from public.erp_tenant_settings s
     where s.tenant_id = p_tenant_id and s.key = 'pdv.cash.withdrawal_limit_amount' and s.establishment_id is null;
    v_limit := coalesce(v_limit, 500);
    if p_amount <= v_limit then
      raise exception 'erp_authorize_cash_action: sangria dentro do limite, sem alcada' using errcode = '23514';
    end if;
    v_amount := p_amount;
    v_threshold := v_limit;
  else
    v_expected := public.erp_cash_session_expected_v1(p_tenant_id, p_cash_session_id);
    v_amount := abs(p_amount - v_expected);
    if v_amount = 0 then
      raise exception 'erp_authorize_cash_action: sem diferenca de caixa, sem alcada' using errcode = '23514';
    end if;
    v_threshold := 0;
  end if;

  v_pin_status := public.erp_check_approver_pin(p_tenant_id, v_approver, p_pin);
  if v_pin_status <> 'ok' then
    return jsonb_build_object('status', v_pin_status);
  end if;

  insert into public.erp_cash_authorizations
    (tenant_id, cash_session_id, kind, amount, threshold_amount, reason, requested_by, approved_by)
  values
    (p_tenant_id, p_cash_session_id, p_kind, v_amount, v_threshold, p_reason, p_requested_by, v_approver)
  returning id into v_id;

  return jsonb_build_object('status', 'authorized', 'authorization_id', v_id);
end;
$$;

revoke all on function public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text, text) from public, anon;
grant execute on function public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text, text) to authenticated;
