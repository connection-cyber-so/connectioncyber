-- M25-G0: fundacao de assinatura SaaS (Mercado Pago Preapproval) + auto-provisionamento.
-- Decisoes do portao: cobranca mensal recorrente com cartao salvo (Preapproval), empresa
-- criada AUTOMATICAMENTE ao primeiro pagamento aprovado, encadeando as RPCs service_role
-- da 0034 (prepare -> record -> finalize). O modelo comercial e parametrizado em
-- saas_plans/saas_plan_capabilities; o seed do plano "padrao" traz price_cents=19900 como
-- PLACEHOLDER ajustavel pelo responsavel (update saas_plans set price_cents=... where code='padrao').
begin;

create table public.saas_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9][a-z0-9_-]{1,60}$'),
  name text not null check (length(name) between 2 and 120),
  description text check (description is null or length(description) <= 2000),
  price_cents integer not null check (price_cents >= 100),
  currency text not null default 'BRL' check (currency = 'BRL'),
  trial_days integer not null default 0 check (trial_days between 0 and 90),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.saas_plan_capabilities (
  plan_id uuid not null references public.saas_plans(id) on delete cascade,
  capability_key text not null references public.erp_capability_catalog(key),
  primary key (plan_id, capability_key)
);

create table public.saas_checkout_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  plan_id uuid not null references public.saas_plans(id),
  status text not null default 'created'
    check (status in ('created','sent','processing','provisioned','failed','expired')),
  tenant_payload jsonb not null,
  request_hash text not null check (request_hash ~ '^[a-f0-9]{64}$'),
  mp_preapproval_id text unique
    check (mp_preapproval_id is null or length(mp_preapproval_id) between 1 and 200),
  mp_customer_id text check (mp_customer_id is null or length(mp_customer_id) between 1 and 200),
  provisioning_run_id uuid references public.erp_identity_provisioning_runs(id),
  tenant_id uuid references public.tenants(id),
  last_error text check (last_error is null or length(last_error) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'provisioned') = (tenant_id is not null)),
  check (status <> 'sent' or mp_preapproval_id is not null),
  check (status <> 'failed' or last_error is not null)
);
create unique index saas_checkout_intents_open_per_user_plan
  on saas_checkout_intents(user_id, plan_id) where status in ('created','sent','processing');

create table public.saas_subscriptions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.saas_plans(id),
  tenant_id uuid not null references public.tenants(id),
  intent_id uuid not null unique references public.saas_checkout_intents(id),
  owner_user_id uuid not null references public.users(id),
  status text not null check (status in ('active','past_due','cancelled','paused')),
  mp_preapproval_id text not null unique
    check (length(mp_preapproval_id) between 1 and 200),
  mp_customer_id text check (mp_customer_id is null or length(mp_customer_id) between 1 and 200),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'cancelled' or cancelled_at is not null),
  check (current_period_end is null or current_period_start is null
         or current_period_end > current_period_start)
);
create index saas_subscriptions_tenant_idx on saas_subscriptions(tenant_id, status);

create table public.saas_billing_events (
  id uuid primary key default gen_random_uuid(),
  topic text not null check (topic in ('preapproval','preapproval_payment')),
  external_id text not null check (length(external_id) between 1 and 200),
  preapproval_id text check (preapproval_id is null or length(preapproval_id) between 1 and 200),
  payment_id text check (payment_id is null or length(payment_id) between 1 and 200),
  status text check (status is null or length(status) between 1 and 60),
  payload jsonb not null,
  processed_at timestamptz,
  result text check (result is null or length(result) between 1 and 500),
  created_at timestamptz not null default now(),
  unique (topic, external_id)
);

create trigger trg_saas_plans_updated_at before update on public.saas_plans
  for each row execute function public.set_updated_at();
create trigger trg_saas_checkout_intents_updated_at before update on public.saas_checkout_intents
  for each row execute function public.set_updated_at();
create trigger trg_saas_subscriptions_updated_at before update on public.saas_subscriptions
  for each row execute function public.set_updated_at();

alter table public.saas_plans enable row level security;
alter table public.saas_plan_capabilities enable row level security;
alter table public.saas_checkout_intents enable row level security;
alter table public.saas_subscriptions enable row level security;
alter table public.saas_billing_events enable row level security;

-- Catalogo de planos e legiveis publicamente (site /planos); DML exclusiva de service_role.
create policy saas_plans_select_public on public.saas_plans for select using (active = true);
create policy saas_plan_capabilities_select_public on public.saas_plan_capabilities
  for select using (exists (select 1 from public.saas_plans p
                            where p.id = plan_id and p.active = true));

revoke all on public.saas_checkout_intents, public.saas_subscriptions, public.saas_billing_events
  from public, anon, authenticated;
grant select on public.saas_plans, public.saas_plan_capabilities to anon, authenticated;
revoke insert, update, delete on public.saas_plans, public.saas_plan_capabilities
  from anon, authenticated;
grant all on public.saas_plans, public.saas_plan_capabilities,
  public.saas_checkout_intents, public.saas_subscriptions, public.saas_billing_events
  to service_role;

-- 1) Cria a intencao de checkout a partir do cadastro do usuario (site, service_role).
create or replace function public.saas_create_checkout_intent_v1(
  p_user_id uuid, p_plan_code text, p_tenant_payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_plan public.saas_plans%rowtype;
  v_open public.saas_checkout_intents%rowtype;
  v_hash text;
  v_allowed text[] := array['slug','domain','displayName','vertical','legalName',
                            'tradeName','cnpj','stateRegistration','establishmentCode'];
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;
  if not exists (select 1 from public.users where id = p_user_id) then
    raise exception using errcode = '55000', message = 'owner identity not ready';
  end if;
  select * into v_plan from public.saas_plans where code = p_plan_code and active for update;
  if not found then raise exception using errcode = '22023', message = 'plan not available'; end if;
  if jsonb_typeof(p_tenant_payload) <> 'object'
     or (p_tenant_payload - v_allowed) <> '{}'::jsonb
     or p_tenant_payload::text ~* '"(password|senha|secret|token|credential|private_key|service_role|certificate|pfx|p12|csc)"[[:space:]]*:'
     or coalesce(p_tenant_payload->>'slug','') !~ '^[a-z][a-z0-9-]{2,63}$'
     or coalesce(p_tenant_payload->>'domain','') !~ '^[a-z0-9-]+(\.[a-z0-9-]+)+$'
     or coalesce(p_tenant_payload->>'cnpj','') !~ '^[0-9]{14}$'
     or coalesce(p_tenant_payload->>'displayName','') !~ '^.{2,120}$'
     or coalesce(p_tenant_payload->>'vertical','') !~ '^[a-z][a-z0-9_-]{1,60}$'
     or coalesce(p_tenant_payload->>'legalName','') !~ '^.{2,160}$'
     or coalesce(p_tenant_payload->>'tradeName','') !~ '^.{2,160}$'
     or coalesce(p_tenant_payload->>'establishmentCode','') !~ '^[A-Za-z0-9][A-Za-z0-9_-]{1,30}$'
     or coalesce(p_tenant_payload->>'stateRegistration','') !~ '^[A-Z0-9]{2,20}$' then
    raise exception using errcode = '22023', message = 'invalid tenant payload';
  end if;
  if exists (select 1 from public.tenants where slug = p_tenant_payload->>'slug'
             or lower(dominio) = lower(p_tenant_payload->>'domain'))
     or exists (select 1 from public.erp_establishments
                where cnpj = p_tenant_payload->>'cnpj') then
    raise exception using errcode = '23505', message = 'tenant already exists';
  end if;
  select * into v_open from public.saas_checkout_intents
   where user_id = p_user_id and plan_id = v_plan.id
     and status in ('created','sent','processing') for update;
  if found then
    if v_open.status in ('created','sent') and v_open.tenant_payload <> p_tenant_payload then
      v_hash := encode(extensions.digest(convert_to(p_tenant_payload::text, 'UTF8'), 'sha256'), 'hex');
      update public.saas_checkout_intents
         set tenant_payload = p_tenant_payload, request_hash = v_hash
       where id = v_open.id
      returning * into v_open;
    end if;
    return jsonb_build_object('intentId', v_open.id, 'replayed', true,
                              'priceCents', v_plan.price_cents, 'planCode', v_plan.code);
  end if;
  v_hash := encode(extensions.digest(convert_to(p_tenant_payload::text, 'UTF8'), 'sha256'), 'hex');
  insert into public.saas_checkout_intents(user_id, plan_id, status, tenant_payload, request_hash)
  values (p_user_id, v_plan.id, 'created', p_tenant_payload, v_hash)
  returning * into v_open;
  return jsonb_build_object('intentId', v_open.id, 'replayed', false,
                            'priceCents', v_plan.price_cents, 'planCode', v_plan.code);
end $$;

-- 2) Associa o Preapproval devolvido pelo Mercado Pago a intencao aberta.
create or replace function public.saas_bind_preapproval_v1(
  p_intent_id uuid, p_preapproval_id text, p_customer_id text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_intent public.saas_checkout_intents%rowtype;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;
  if coalesce(p_preapproval_id,'') !~ '^[A-Za-z0-9-]{4,100}$' then
    raise exception using errcode = '22023', message = 'invalid preapproval id';
  end if;
  select * into v_intent from public.saas_checkout_intents where id = p_intent_id for update;
  if not found then raise exception using errcode = '55000', message = 'intent not found'; end if;
  if v_intent.status = 'provisioned' then
    return jsonb_build_object('intentId', v_intent.id, 'status', v_intent.status, 'replayed', true);
  end if;
  if v_intent.status not in ('created','sent') then
    raise exception using errcode = '55000', message = 'intent not bindable';
  end if;
  if exists (select 1 from public.saas_checkout_intents
             where mp_preapproval_id = p_preapproval_id and id <> v_intent.id) then
    raise exception using errcode = '23505', message = 'preapproval already bound';
  end if;
  update public.saas_checkout_intents
     set status = 'sent', mp_preapproval_id = p_preapproval_id,
         mp_customer_id = nullif(p_customer_id, '')
   where id = v_intent.id
  returning * into v_intent;
  return jsonb_build_object('intentId', v_intent.id, 'status', v_intent.status, 'replayed', false);
end $$;

-- 3) Ativa a assinatura e provisiona a empresa (primeiro pagamento aprovado).
--    Encadeia 0034: prepare -> record -> finalize. Idempotente por intent.
create or replace function public.saas_activate_intent_v1(p_preapproval_id text, p_period_end timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_intent public.saas_checkout_intents%rowtype;
  v_plan public.saas_plans%rowtype;
  v_request jsonb;
  v_prepared jsonb;
  v_run uuid;
  v_caps text[];
  v_sub public.saas_subscriptions%rowtype;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;
  if coalesce(p_preapproval_id,'') !~ '^[A-Za-z0-9-]{4,100}$' then
    raise exception using errcode = '22023', message = 'invalid preapproval id';
  end if;
  select * into v_intent from public.saas_checkout_intents
   where mp_preapproval_id = p_preapproval_id for update;
  if not found then raise exception using errcode = '55000', message = 'intent not found'; end if;
  if v_intent.status = 'provisioned' then
    select * into v_sub from public.saas_subscriptions where intent_id = v_intent.id;
    return jsonb_build_object('intentId', v_intent.id, 'tenantId', v_intent.tenant_id,
                              'subscriptionId', v_sub.id, 'replayed', true,
                              'status', v_sub.status);
  end if;
  if v_intent.status = 'processing' then
    raise exception using errcode = '55000', message = 'activation in progress';
  end if;
  if v_intent.status not in ('sent','failed') then
    raise exception using errcode = '55000', message = 'intent not activable';
  end if;
  if p_period_end is not null and p_period_end <= now() then
    raise exception using errcode = '22023', message = 'invalid period';
  end if;
  select * into v_plan from public.saas_plans where id = v_intent.plan_id;
  select array_agg(capability_key order by capability_key) into v_caps
    from public.saas_plan_capabilities where plan_id = v_plan.id;
  if v_caps is null or coalesce(cardinality(v_caps), 0) = 0 then
    raise exception using errcode = '22023', message = 'plan without capabilities';
  end if;
  update public.saas_checkout_intents set status = 'processing', last_error = null
   where id = v_intent.id;

  v_request := jsonb_build_object(
    'idempotencyKey', 'saas.' || v_intent.id,
    'slug', v_intent.tenant_payload->>'slug',
    'domain', v_intent.tenant_payload->>'domain',
    'displayName', v_intent.tenant_payload->>'displayName',
    'vertical', v_intent.tenant_payload->>'vertical',
    'legalName', v_intent.tenant_payload->>'legalName',
    'tradeName', v_intent.tenant_payload->>'tradeName',
    'cnpj', v_intent.tenant_payload->>'cnpj',
    'stateRegistration', v_intent.tenant_payload->>'stateRegistration',
    'establishmentCode', v_intent.tenant_payload->>'establishmentCode',
    'ownerSubjectKey', 'owner.' || v_intent.user_id,
    'ownerEmailRef', 'protected:SAAS_OWNER',
    'capabilities', to_jsonb(v_caps));

  v_prepared := public.erp_prepare_pilot_provisioning_v1(v_request);
  v_run := (v_prepared->>'runId')::uuid;
  perform public.erp_record_pilot_auth_identity_v1(v_run, v_intent.user_id);
  perform public.erp_finalize_pilot_identity_v1(v_run, v_intent.user_id);

  insert into public.saas_subscriptions(
    plan_id, tenant_id, intent_id, owner_user_id, status, mp_preapproval_id, mp_customer_id,
    current_period_start, current_period_end)
  values (v_plan.id, (v_prepared->>'tenantId')::uuid, v_intent.id, v_intent.user_id, 'active',
          v_intent.mp_preapproval_id, v_intent.mp_customer_id, now(), p_period_end)
  returning * into v_sub;

  update public.saas_checkout_intents
     set status = 'provisioned', provisioning_run_id = v_run,
         tenant_id = (v_prepared->>'tenantId')::uuid, last_error = null
   where id = v_intent.id
  returning * into v_intent;

  return jsonb_build_object('intentId', v_intent.id, 'tenantId', v_intent.tenant_id,
                            'subscriptionId', v_sub.id, 'runId', v_run,
                            'replayed', false, 'status', v_sub.status);
exception when others then
  update public.saas_checkout_intents
     set status = 'failed', last_error = left(coalesce(sqlerrm, 'activation failed'), 500)
   where id = v_intent.id and status = 'processing';
  raise;
end $$;

-- 4) Suspende (inadimplencia/cancelamento) ou reativa as capabilities do plano.
create or replace function public.saas_set_subscription_status_v1(
  p_preapproval_id text, p_status text, p_reason text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_sub public.saas_subscriptions%rowtype;
  v_key text;
  v_cap text;
  v_target text;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;
  if p_status not in ('active','past_due','cancelled','paused') then
    raise exception using errcode = '22023', message = 'invalid status';
  end if;
  if p_reason is null or length(btrim(p_reason)) not between 1 and 500 then
    raise exception using errcode = '22023', message = 'invalid reason';
  end if;
  select * into v_sub from public.saas_subscriptions
   where mp_preapproval_id = p_preapproval_id for update;
  if not found then raise exception using errcode = '55000', message = 'subscription not found'; end if;
  if v_sub.status = 'cancelled' and p_status = 'cancelled' then
    return jsonb_build_object('subscriptionId', v_sub.id, 'status', v_sub.status, 'replayed', true);
  end if;
  update public.saas_subscriptions
     set status = p_status,
         cancelled_at = case when p_status = 'cancelled' then now() else cancelled_at end
   where id = v_sub.id
  returning * into v_sub;
  if p_status in ('cancelled','paused','past_due') then v_target := 'suspended';
  else v_target := 'active'; end if;
  for v_cap in
    select capability_key from public.saas_plan_capabilities where plan_id = v_sub.plan_id
  loop
    v_key := v_cap;
    perform public.erp_set_tenant_capability(v_sub.tenant_id, v_key, v_target,
      'contract', 1, encode(extensions.digest(convert_to(v_sub.id::text || ':' || v_key || ':' || p_status, 'UTF8'), 'sha256'), 'hex'));
  end loop;
  return jsonb_build_object('subscriptionId', v_sub.id, 'status', v_sub.status,
                            'capabilityState', v_target, 'replayed', false);
end $$;

-- 5) Registro idempotente da notificacao do Mercado Pago (auditoria do webhook).
create or replace function public.saas_record_billing_event_v1(
  p_topic text, p_external_id text, p_preapproval_id text, p_payment_id text,
  p_status text, p_payload jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;
  if p_topic not in ('preapproval','preapproval_payment')
     or p_payload is null or jsonb_typeof(p_payload) <> 'object'
     or coalesce(p_external_id,'') !~ '^[A-Za-z0-9_.:-]{1,200}$' then
    raise exception using errcode = '22023', message = 'invalid billing event';
  end if;
  insert into public.saas_billing_events(topic, external_id, preapproval_id, payment_id, status, payload)
  values (p_topic, p_external_id, nullif(p_preapproval_id,''), nullif(p_payment_id,''),
          nullif(p_status,''), p_payload)
  on conflict (topic, external_id) do nothing
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.saas_mark_billing_event_processed_v1(
  p_topic text, p_external_id text, p_result text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;
  update public.saas_billing_events
     set processed_at = now(), result = left(coalesce(p_result, 'ok'), 500)
   where topic = p_topic and external_id = p_external_id and processed_at is null;
end $$;

revoke all on function public.saas_create_checkout_intent_v1(uuid, text, jsonb),
  public.saas_bind_preapproval_v1(uuid, text, text),
  public.saas_activate_intent_v1(text, timestamptz),
  public.saas_set_subscription_status_v1(text, text, text),
  public.saas_record_billing_event_v1(text, text, text, text, text, jsonb),
  public.saas_mark_billing_event_processed_v1(text, text, text)
  from public, anon, authenticated;
grant execute on function public.saas_create_checkout_intent_v1(uuid, text, jsonb),
  public.saas_bind_preapproval_v1(uuid, text, text),
  public.saas_activate_intent_v1(text, timestamptz),
  public.saas_set_subscription_status_v1(text, text, text),
  public.saas_record_billing_event_v1(text, text, text, text, text, jsonb),
  public.saas_mark_billing_event_processed_v1(text, text, text)
  to service_role;

-- Seed do plano comercial (PLACEHOLDER de preco: ajustar pelo responsavel).
insert into public.saas_plans(code, name, description, price_cents, trial_days)
values ('padrao', 'Plano Padrao ConnectionCyber',
        'ERP multiempresa com cadastros, estoque, vendas, PDV, financeiro, fiscal e academia.',
        19900, 0);
insert into public.saas_plan_capabilities(plan_id, capability_key)
select p.id, c.key
  from public.saas_plans p
  join public.erp_capability_catalog c on c.key in (
    'core.organization','core.parties','core.catalog','core.pricing','inventory.stock',
    'sales.orders','sales.quotes','sales.pos','finance','fiscal','migration',
    'academy.courses','support.tickets')
 where p.code = 'padrao';

commit;
