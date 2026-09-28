-- =============================================================================
-- ConnectionCyber — M04-G1: identidade, RBAC, MFA e provisionamento auditável
--
-- ESCOPO ADITIVO/HARDENING:
--   - remove tenant como autoridade de metadata/JWT;
--   - permite profile Auth ainda sem tenant legado;
--   - restringe atualização de public.users a campos de apresentação;
--   - acrescenta lifecycle e exigência MFA ao RBAC ERP;
--   - cria ledger server-only para provisionamento idempotente;
--   - oferece helper AAL1/AAL2 para autorização sensível.
--
-- FORA DE ESCOPO DESTE PORTÃO:
--   criação de usuários, convites, memberships, roles por tenant, fatores MFA,
--   configuração remota do Auth e qualquer dado real.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. PROFILE SEM AUTORIDADE DE TENANT NO SIGNUP
-- -----------------------------------------------------------------------------

-- users.tenant_id permanece como ponte de compatibilidade do site/painel antigo,
-- mas deixa de ser obrigatório e nunca autoriza o ERP. O ERP usa memberships.
alter table public.users alter column tenant_id drop not null;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name text;
begin
  if new.email is null or btrim(new.email) = '' then
    raise exception 'IDENTITY_EMAIL_REQUIRED' using errcode = '23514';
  end if;

  display_name := coalesce(
    nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    split_part(lower(new.email), '@', 1)
  );

  insert into public.users (id, nome, email, tenant_id)
  values (new.id, display_name, lower(new.email), null)
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Cria somente o profile da identidade. Ignora tenant_id em metadata e não aplica fallback; memberships são provisionadas server-only.';

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- O hook histórico deixa de gravar tenant único. Se estiver habilitado no Auth,
-- remove apenas a claim legada tenant_id e preserva as demais claims.
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  claims jsonb := coalesce(event->'claims', '{}'::jsonb);
  app_metadata jsonb := coalesce(claims->'app_metadata', '{}'::jsonb);
begin
  app_metadata := app_metadata - 'tenant_id';
  claims := jsonb_set(claims, '{app_metadata}', app_metadata, true);
  return jsonb_set(event, '{claims}', claims, true);
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Preserva claims do Auth e remove tenant_id legado. Tenant ativo é resolvido por hostname + membership no servidor.';

grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb)
  from authenticated, anon, public;

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select profile.tenant_id
  from public.users profile
  where profile.id = (select auth.uid())
$$;

comment on function public.current_tenant_id() is
  'Ponte legada nullable. Não usar para autorização ERP; o ERP usa erp_tenant_memberships.';

revoke execute on function public.current_tenant_id() from public, anon;
grant execute on function public.current_tenant_id() to authenticated, service_role;

-- Policies antigas eram concedidas ao pseudo-papel public e permitiam alterar
-- tenant_id, email e ativo. A partir daqui o usuário edita só nome/idioma.
drop policy if exists "usuário vê o próprio perfil" on public.users;
drop policy if exists "usuário atualiza o próprio perfil" on public.users;
drop policy if exists users_select_self on public.users;
drop policy if exists users_update_self_profile on public.users;

create policy users_select_self
  on public.users for select to authenticated
  using (id = (select auth.uid()));

create policy users_update_self_profile
  on public.users for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

revoke all on table public.users from anon, authenticated;
grant select on table public.users to authenticated;
grant update (nome, idioma_preferido) on table public.users to authenticated;
grant all on table public.users to service_role;

-- -----------------------------------------------------------------------------
-- 2. LIFECYCLE E MFA NO RBAC ERP
-- -----------------------------------------------------------------------------

alter table public.erp_tenant_memberships
  add column invited_at timestamptz,
  add column activated_at timestamptz,
  add column suspended_at timestamptz,
  add column revoked_at timestamptz,
  add column invitation_expires_at timestamptz,
  add constraint erp_membership_invitation_period_valid
    check (invitation_expires_at is null or invited_at is null or invitation_expires_at > invited_at);

alter table public.erp_roles
  add column requires_mfa boolean not null default false,
  add column sensitivity text not null default 'standard'
    check (sensitivity in ('standard', 'privileged')),
  add constraint erp_roles_privileged_mfa_required
    check (
      requires_mfa
      or (sensitivity = 'standard' and key not in ('owner', 'admin'))
    );

insert into public.erp_permissions (key, name, description, category)
values
  ('identities.read', 'Consultar identidades', 'Consulta segura de identidades e lifecycle.', 'identity'),
  ('identities.manage', 'Gerenciar identidades', 'Convites, ativação, suspensão e revogação.', 'identity'),
  ('roles.assign', 'Atribuir papéis', 'Atribui ou remove papéis de memberships.', 'authorization'),
  ('mfa.read', 'Consultar MFA', 'Consulta apenas estado de garantia, nunca segredo do fator.', 'identity'),
  ('mfa.enforce', 'Exigir MFA', 'Define e fiscaliza step-up em ações privilegiadas.', 'authorization')
on conflict (key) do nothing;

-- -----------------------------------------------------------------------------
-- 3. LEDGER SERVER-ONLY DO PROVISIONAMENTO
-- -----------------------------------------------------------------------------

create table public.erp_identity_provisioning_runs (
  id                uuid primary key default gen_random_uuid(),
  idempotency_key   text not null unique
                    check (idempotency_key ~ '^[a-z0-9][a-z0-9._:-]{7,127}$'),
  manifest_sha256   text not null check (manifest_sha256 ~ '^[0-9a-f]{64}$'),
  schema_version    integer not null check (schema_version > 0),
  environment       text not null check (environment in ('staging', 'production')),
  execution_mode    text not null check (execution_mode in ('dry_run', 'apply')),
  status            text not null default 'planned'
                    check (status in ('planned', 'running', 'completed', 'failed', 'compensated')),
  requested_by      uuid references public.users(id) on delete restrict,
  correlation_id    uuid not null default gen_random_uuid(),
  subject_count     integer not null default 0 check (subject_count >= 0),
  summary           jsonb not null default '{}'::jsonb check (jsonb_typeof(summary) = 'object'),
  error_code        text,
  started_at        timestamptz,
  finished_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint erp_identity_run_period_valid
    check (finished_at is null or started_at is null or finished_at >= started_at),
  constraint erp_identity_run_finished_status_valid
    check (status in ('planned', 'running') or finished_at is not null),
  constraint erp_identity_run_summary_no_secrets
    check (summary::text !~* '"(password|access_token|refresh_token|service_role|secret|credential|certificate|pfx)"[[:space:]]*:')
);

create table public.erp_identity_provisioning_steps (
  id             bigint generated always as identity primary key,
  run_id         uuid not null references public.erp_identity_provisioning_runs(id) on delete cascade,
  step_key       text not null check (step_key ~ '^[a-z][a-z0-9._:-]{2,127}$'),
  subject_key    text not null check (subject_key ~ '^[a-z][a-z0-9._-]{2,95}$'),
  action         text not null check (action in (
                   'validate_identity', 'create_auth_identity', 'upsert_profile',
                   'upsert_membership', 'assign_roles', 'require_mfa', 'write_audit'
                 )),
  status         text not null default 'planned'
                 check (status in ('planned', 'running', 'completed', 'skipped', 'failed', 'compensated')),
  tenant_id      uuid references public.tenants(id) on delete restrict,
  user_id        uuid references public.users(id) on delete restrict,
  detail         jsonb not null default '{}'::jsonb check (jsonb_typeof(detail) = 'object'),
  started_at     timestamptz,
  finished_at    timestamptz,
  created_at     timestamptz not null default now(),
  constraint erp_identity_step_unique unique (run_id, step_key),
  constraint erp_identity_step_period_valid
    check (finished_at is null or started_at is null or finished_at >= started_at),
  constraint erp_identity_step_detail_no_secrets
    check (detail::text !~* '"(password|access_token|refresh_token|service_role|secret|credential|certificate|pfx)"[[:space:]]*:')
);

create index erp_identity_runs_status_created
  on public.erp_identity_provisioning_runs(status, created_at desc);
create index erp_identity_steps_run_status
  on public.erp_identity_provisioning_steps(run_id, status, id);

create trigger trg_erp_identity_runs_updated_at
  before update on public.erp_identity_provisioning_runs
  for each row execute function public.set_updated_at();

alter table public.erp_identity_provisioning_runs enable row level security;
alter table public.erp_identity_provisioning_steps enable row level security;

-- Nenhuma policy intencionalmente: até existir API auditada, somente service_role.
revoke all on table
  public.erp_identity_provisioning_runs,
  public.erp_identity_provisioning_steps
from public, anon, authenticated;

grant all on table
  public.erp_identity_provisioning_runs,
  public.erp_identity_provisioning_steps
to service_role;
grant usage, select on sequence public.erp_identity_provisioning_steps_id_seq
  to service_role;

-- -----------------------------------------------------------------------------
-- 4. AUTORIZAÇÃO COM NÍVEL DE GARANTIA (AAL)
-- -----------------------------------------------------------------------------

create or replace function erp_security.current_aal()
returns text
language sql
stable
security invoker
set search_path = ''
as $$
  select case coalesce(
    nullif(current_setting('request.jwt.claim.aal', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb)->>'aal',
    ''
  )
    when 'aal2' then 'aal2'
    when 'aal1' then 'aal1'
    else 'aal0'
  end
$$;

create or replace function erp_security.has_permission_at_aal(
  p_tenant_id uuid,
  p_permission_key text,
  p_required_aal text default 'aal1'
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_required_aal in ('aal1', 'aal2')
    and erp_security.has_permission(p_tenant_id, p_permission_key)
    and case p_required_aal
      when 'aal2' then erp_security.current_aal() = 'aal2'
      else erp_security.current_aal() in ('aal1', 'aal2')
    end
$$;

revoke execute on function erp_security.current_aal() from public, anon;
revoke execute on function erp_security.has_permission_at_aal(uuid, text, text)
  from public, anon;
grant execute on function erp_security.current_aal() to authenticated, service_role;
grant execute on function erp_security.has_permission_at_aal(uuid, text, text)
  to authenticated, service_role;

comment on table public.erp_identity_provisioning_runs is
  'Ledger server-only e idempotente de dry-run/apply. O M04-G1 entrega somente dry-run e não cria registros remotos.';
comment on table public.erp_identity_provisioning_steps is
  'Passos retomáveis do provisionamento. Proíbe segredos em detail e não possui policy client-side.';
comment on column public.users.tenant_id is
  'Compatibilidade legada nullable. Não concede acesso ERP; use erp_tenant_memberships.';
comment on function erp_security.current_aal() is
  'Normaliza a claim aal da sessão em aal0, aal1 ou aal2.';
comment on function erp_security.has_permission_at_aal(uuid, text, text) is
  'Exige membership, permissão explícita e AAL mínimo para ação sensível.';

commit;
