-- 0066 · PDV · alçada de caixa: sangria acima do limite e fechamento com diferença
-- Escopo:
--   1) erp_cash_authorizations: autorização registrada por outra pessoa (aprovador ≠ solicitante).
--   2) Sangria (withdrawal): exige cash.adjust; acima de pdv.cash.withdrawal_limit_amount exige autorização
--      de mesmo valor, do próprio operador, usada uma única vez (trigger em erp_cash_movements).
--   3) Fechamento: diferença entre contado e esperado exige autorização de fechamento com o valor exato da diferença.
--      erp_command_close_cash_v1 passa a aceitar 'authorizationId' no payload e grava a diferença real.
--   4) RPC erp_authorize_cash_action: única forma de gravar a autorização.
-- Decisões propostas (validar com o responsável):
--   - Limite de sangria sem autorização: 500,00 por padrão (pdv.cash.withdrawal_limit_amount).
--   - Qualquer diferença de caixa (≠ 0) exige autorização de fechamento. Não há tolerância automática.
-- Fora deste gate: PIN/MFA do aprovador; alçada de suprimento e de estorno.

-- Pré-requisito já existente: erp_cash_sessions_tenant_id_id_key unique (tenant_id, id) (verificado no staging).

-- 1) Autorizações de caixa
create table public.erp_cash_authorizations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  cash_session_id uuid not null,
  kind text not null,
  amount numeric(19,4) not null,
  threshold_amount numeric(19,4) not null default 0,
  reason text not null,
  requested_by uuid not null,
  approved_by uuid not null,
  created_at timestamptz not null default now(),
  constraint erp_cash_authorizations_tenant_id_id_key unique (tenant_id, id),
  constraint erp_cash_authorizations_session_fk
    foreign key (tenant_id, cash_session_id) references public.erp_cash_sessions (tenant_id, id) on delete restrict,
  constraint erp_cash_authorizations_kind_check check (kind in ('withdrawal', 'close')),
  constraint erp_cash_authorizations_amount_check check (amount > 0),
  constraint erp_cash_authorizations_threshold_check check (threshold_amount >= 0),
  constraint erp_cash_authorizations_reason_check check (length(btrim(reason)) >= 3),
  constraint erp_cash_authorizations_separation_check check (approved_by <> requested_by)
);

alter table public.erp_cash_authorizations enable row level security;

create policy erp_cash_authorizations_select on public.erp_cash_authorizations
  for select to authenticated
  using (
    (select erp_security.has_permission(tenant_id, 'cash.read'))
    or (select erp_security.has_permission(tenant_id, 'cash.adjust'))
    or (select erp_security.has_permission(tenant_id, 'cash.close'))
    or (select public.is_platform_staff())
  );

revoke all on public.erp_cash_authorizations from anon, authenticated;
grant select on public.erp_cash_authorizations to authenticated;

-- 2) Vínculos: sangria e fechamento consomem a autorização uma única vez
alter table public.erp_cash_movements add column if not exists authorization_id uuid;
alter table public.erp_cash_movements
  add constraint erp_cash_movements_authorization_fk
    foreign key (tenant_id, authorization_id) references public.erp_cash_authorizations (tenant_id, id) on delete restrict;
create unique index erp_cash_movements_authorization_key
  on public.erp_cash_movements (tenant_id, authorization_id) where authorization_id is not null;

alter table public.erp_cash_sessions add column if not exists closing_authorization_id uuid;
alter table public.erp_cash_sessions
  add constraint erp_cash_sessions_closing_authorization_fk
    foreign key (tenant_id, closing_authorization_id) references public.erp_cash_authorizations (tenant_id, id) on delete restrict;
create unique index erp_cash_sessions_closing_authorization_key
  on public.erp_cash_sessions (tenant_id, closing_authorization_id) where closing_authorization_id is not null;

-- 3) Saldo esperado da sessão (mesma fórmula do fechamento)
create or replace function public.erp_cash_session_expected_v1(p_tenant_id uuid, p_session_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select s.opening_amount + coalesce(sum(case when m.direction = 'in' then m.amount else -m.amount end), 0)
    from public.erp_cash_sessions s
    left join public.erp_cash_movements m
      on m.tenant_id = s.tenant_id and m.cash_session_id = s.id and m.type <> 'opening'
   where s.tenant_id = p_tenant_id and s.id = p_session_id
   group by s.opening_amount
$$;

revoke all on function public.erp_cash_session_expected_v1(uuid, uuid) from public, anon, authenticated;

-- 4) Guarda de sangria (trigger em erp_cash_movements)
create or replace function public.erp_cash_movements_guard_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit numeric;
  a public.erp_cash_authorizations%rowtype;
begin
  if new.type = 'withdrawal' then
    if not (select erp_security.has_permission(new.tenant_id, 'cash.adjust'))
       and not (select public.is_platform_staff()) then
      raise exception 'erp_cash_movements: sangria exige permissao cash.adjust'
        using errcode = '42501';
    end if;

    select coalesce((s.value ->> 'amount')::numeric, 500) into v_limit
      from public.erp_tenant_settings s
     where s.tenant_id = new.tenant_id
       and s.key = 'pdv.cash.withdrawal_limit_amount'
       and s.establishment_id is null;
    v_limit := coalesce(v_limit, 500);

    if new.amount > v_limit then
      if new.authorization_id is null then
        raise exception 'erp_cash_movements: sangria acima do limite exige autorizacao'
          using errcode = '23514';
      end if;

      select * into a from public.erp_cash_authorizations
       where tenant_id = new.tenant_id and id = new.authorization_id;

      if not found
         or a.kind <> 'withdrawal'
         or a.cash_session_id <> new.cash_session_id
         or a.amount <> new.amount
         or a.requested_by <> (select auth.uid()) then
        raise exception 'erp_cash_movements: autorizacao de sangria invalida para esta sangria'
          using errcode = '23514';
      end if;
    elsif new.authorization_id is not null then
      raise exception 'erp_cash_movements: autorizacao informada para sangria dentro do limite'
        using errcode = '23514';
    end if;
  elsif new.authorization_id is not null then
    raise exception 'erp_cash_movements: autorizacao so vale para sangria'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function public.erp_cash_movements_guard_v1() from public, anon, authenticated;

create trigger erp_cash_movements_guard_trg
  before insert on public.erp_cash_movements
  for each row execute function public.erp_cash_movements_guard_v1();

-- 5) Verificação da diferença no fechamento (chamada por erp_command_close_cash_v1)
create or replace function public.erp_assert_cash_close_authorized_v1(
  p_tenant_id uuid,
  p_session_id uuid,
  p_expected numeric,
  p_counted numeric,
  p_authorization_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.erp_cash_authorizations%rowtype;
begin
  if p_counted = p_expected then
    return;
  end if;

  if p_authorization_id is null then
    raise exception 'cash difference requires authorization'
      using errcode = '23514';
  end if;

  select * into a from public.erp_cash_authorizations
   where tenant_id = p_tenant_id and id = p_authorization_id;

  if not found
     or a.kind <> 'close'
     or a.cash_session_id <> p_session_id
     or a.amount <> abs(p_counted - p_expected)
     or a.requested_by <> (select auth.uid()) then
    raise exception 'cash close authorization invalid'
      using errcode = '23514';
  end if;

  if exists (
    select 1 from public.erp_cash_sessions s
     where s.tenant_id = p_tenant_id and s.closing_authorization_id = p_authorization_id
  ) then
    raise exception 'cash close authorization already used'
      using errcode = '23514';
  end if;
end;
$$;

revoke all on function public.erp_assert_cash_close_authorized_v1(uuid, uuid, numeric, numeric, uuid) from public, anon, authenticated;

-- 6) RPC de autorização: única forma de gravar erp_cash_authorizations
create or replace function public.erp_authorize_cash_action(
  p_tenant_id uuid,
  p_cash_session_id uuid,
  p_kind text,
  p_amount numeric,
  p_requested_by uuid,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approver uuid := (select auth.uid());
  v_perm text;
  v_status text;
  v_expected numeric;
  v_limit numeric;
  v_amount numeric;
  v_threshold numeric;
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

  select s.status into v_status
    from public.erp_cash_sessions s
   where s.tenant_id = p_tenant_id and s.id = p_cash_session_id;
  if not found then
    raise exception 'erp_authorize_cash_action: sessao de caixa nao encontrada' using errcode = 'P0002';
  end if;
  if v_status = 'closed' then
    raise exception 'erp_authorize_cash_action: sessao ja fechada' using errcode = '55000';
  end if;

  if p_kind = 'withdrawal' then
    select coalesce((s.value ->> 'amount')::numeric, 500) into v_limit
      from public.erp_tenant_settings s
     where s.tenant_id = p_tenant_id
       and s.key = 'pdv.cash.withdrawal_limit_amount'
       and s.establishment_id is null;
    v_limit := coalesce(v_limit, 500);
    if p_amount <= v_limit then
      raise exception 'erp_authorize_cash_action: sangria dentro do limite, sem alcada' using errcode = '23514';
    end if;
    v_amount := p_amount;
    v_threshold := v_limit;
  else
    -- Para fechamento, p_amount é o valor CONTADO. A autorização registra a diferença absoluta.
    v_expected := public.erp_cash_session_expected_v1(p_tenant_id, p_cash_session_id);
    v_amount := abs(p_amount - v_expected);
    if v_amount = 0 then
      raise exception 'erp_authorize_cash_action: sem diferenca de caixa, sem alcada' using errcode = '23514';
    end if;
    v_threshold := 0;
  end if;

  insert into public.erp_cash_authorizations
    (tenant_id, cash_session_id, kind, amount, threshold_amount, reason, requested_by, approved_by)
  values
    (p_tenant_id, p_cash_session_id, p_kind, v_amount, v_threshold, p_reason, p_requested_by, v_approver)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text) from public, anon;
grant execute on function public.erp_authorize_cash_action(uuid, uuid, text, numeric, uuid, text) to authenticated;

-- 7) Fechamento: aceita diferença somente com autorização de fechamento
create or replace function public.erp_command_close_cash_v1(p_tenant_id uuid, p_request_id text, p_payload_hash text, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  c jsonb;
  v public.erp_cash_sessions%rowtype;
  v_expected numeric(19,4);
  v_counted numeric(19,4);
  v_authorization uuid;
  v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'cash.close','sales.pos');
  c := public.erp_claim_command_v1(p_tenant_id,'cash.close',p_request_id,p_payload_hash,p_payload);
  if (c->>'replayed')::boolean then
    return c->'result';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||(p_payload->>'cashSessionId'),0));
  select * into v from public.erp_cash_sessions
   where tenant_id = p_tenant_id and id = (p_payload->>'cashSessionId')::uuid
   for update;
  if not found then
    raise exception using errcode='P0002', message='cash session not found';
  end if;
  if v.status = 'closed' then
    raise exception using errcode='55000', message='cash session already closed';
  end if;
  select v.opening_amount + coalesce(sum(case when m.direction='in' then m.amount else -m.amount end),0)
    into v_expected
    from public.erp_cash_movements m
   where m.tenant_id = p_tenant_id and m.cash_session_id = v.id and m.type <> 'opening';
  v_counted := (p_payload->>'countedAmount')::numeric;
  v_authorization := nullif(p_payload->>'authorizationId', '')::uuid;
  perform public.erp_assert_cash_close_authorized_v1(p_tenant_id, v.id, v_expected, v_counted, v_authorization);
  update public.erp_cash_sessions
     set status = 'closed',
         closed_at = now(),
         expected_amount = v_expected,
         counted_amount = v_counted,
         difference_amount = v_counted - v_expected,
         closing_authorization_id = v_authorization
   where tenant_id = p_tenant_id and id = v.id;
  v_result := jsonb_build_object('status','closed','cashSessionId',v.id,'expectedAmount',v_expected);
  return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end
$function$;

-- 8) Limite padrão de sangria por tenant (idempotente)
insert into public.erp_tenant_settings (tenant_id, establishment_id, key, value, sensitivity, schema_version)
select t.id, null, 'pdv.cash.withdrawal_limit_amount', '{"amount": 500}'::jsonb, 'internal', 1
  from public.tenants t
 where not exists (
   select 1 from public.erp_tenant_settings s
    where s.tenant_id = t.id and s.key = 'pdv.cash.withdrawal_limit_amount' and s.establishment_id is null
 );
