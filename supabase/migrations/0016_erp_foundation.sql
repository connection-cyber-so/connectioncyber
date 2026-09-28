-- =============================================================================
-- ConnectionCyber — M02: fundação ERP multiempresa e multissegmento
--
-- ESCOPO ADITIVO:
--   - memberships multi-tenant;
--   - RBAC do ERP;
--   - estabelecimentos;
--   - catálogo de capacidades e perfis de segmento;
--   - configurações sem segredos;
--   - numeração transacional;
--   - auditoria append-only;
--   - RLS e grants mínimos.
--
-- FORA DE ESCOPO:
--   dados reais, catálogo de produtos, estoque, vendas, financeiro, fiscal,
--   certificado A1, Mercado Pago e importação de backups legados.
--
-- IMPORTANTE: preparar/revisar/testar antes de executar db push. Esta migration
-- não altera as tabelas products/orders/payments do site e não substitui
-- users.tenant_id durante a transição.
-- =============================================================================

begin;

-- Helpers de RLS ficam fora dos schemas expostos pelo Data API.
create schema if not exists erp_security;
revoke all on schema erp_security from public, anon;
grant usage on schema erp_security to authenticated, service_role;
alter default privileges in schema erp_security revoke execute on functions from public;

-- -----------------------------------------------------------------------------
-- 1. MEMBERSHIPS E RBAC DO ERP
-- -----------------------------------------------------------------------------

create table public.erp_tenant_memberships (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants(id) on delete cascade,
  user_id       uuid not null references public.users(id) on delete cascade,
  status        text not null default 'invited'
                check (status in ('invited', 'active', 'suspended', 'revoked')),
  is_default    boolean not null default false,
  starts_at     timestamptz,
  ends_at       timestamptz,
  invited_by    uuid references public.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint erp_membership_period_valid
    check (ends_at is null or starts_at is null or ends_at > starts_at),
  constraint erp_membership_tenant_user_unique unique (tenant_id, user_id),
  constraint erp_membership_tenant_id_unique unique (tenant_id, id),
  constraint erp_membership_tenant_id_user_unique unique (tenant_id, id, user_id)
);

create unique index erp_memberships_one_default_per_user
  on public.erp_tenant_memberships(user_id)
  where is_default and status = 'active';
create index erp_memberships_user_status
  on public.erp_tenant_memberships(user_id, status);
create index erp_memberships_tenant_status
  on public.erp_tenant_memberships(tenant_id, status);

create table public.erp_roles (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id) on delete cascade,
  key         text not null check (key ~ '^[a-z][a-z0-9_.-]{1,63}$'),
  name        text not null,
  description text,
  is_system   boolean not null default false,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint erp_roles_tenant_key_unique unique (tenant_id, key),
  constraint erp_roles_tenant_id_unique unique (tenant_id, id)
);

create table public.erp_permissions (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique check (key ~ '^[a-z][a-z0-9_.-]{1,95}$'),
  name        text not null,
  description text,
  category    text not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table public.erp_role_permissions (
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  role_id      uuid not null,
  permission_id uuid not null references public.erp_permissions(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (tenant_id, role_id, permission_id),
  constraint erp_role_permissions_role_fk
    foreign key (tenant_id, role_id)
    references public.erp_roles(tenant_id, id) on delete cascade
);

create table public.erp_membership_roles (
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  membership_id uuid not null,
  role_id      uuid not null,
  granted_by   uuid references public.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  primary key (tenant_id, membership_id, role_id),
  constraint erp_membership_roles_membership_fk
    foreign key (tenant_id, membership_id)
    references public.erp_tenant_memberships(tenant_id, id) on delete cascade,
  constraint erp_membership_roles_role_fk
    foreign key (tenant_id, role_id)
    references public.erp_roles(tenant_id, id) on delete cascade
);

-- -----------------------------------------------------------------------------
-- 2. ORGANIZAÇÃO, CAPACIDADES E PERFIS
-- -----------------------------------------------------------------------------

create table public.erp_establishments (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references public.tenants(id) on delete cascade,
  code              text not null check (code ~ '^[A-Z0-9][A-Z0-9_-]{0,31}$'),
  kind              text not null default 'branch'
                    check (kind in ('headquarters', 'branch', 'unit')),
  legal_name        text,
  trade_name        text not null,
  cnpj              text check (cnpj is null or cnpj ~ '^[0-9]{14}$'),
  timezone          text not null default 'America/Sao_Paulo',
  currency_code     text not null default 'BRL'
                    check (currency_code ~ '^[A-Z]{3}$'),
  operational_cutoff time not null default '00:00:00',
  active            boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint erp_establishments_tenant_code_unique unique (tenant_id, code),
  constraint erp_establishments_tenant_id_unique unique (tenant_id, id)
);

create unique index erp_establishments_cnpj_unique
  on public.erp_establishments(cnpj)
  where cnpj is not null;

create table public.erp_capability_catalog (
  key           text primary key check (key ~ '^[a-z][a-z0-9_.-]{1,95}$'),
  name          text not null,
  description   text,
  category      text not null,
  version       integer not null default 1 check (version > 0),
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.erp_tenant_capabilities (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants(id) on delete cascade,
  capability_key text not null references public.erp_capability_catalog(key) on delete restrict,
  status         text not null default 'disabled'
                 check (status in ('trial', 'active', 'suspended', 'disabled')),
  config         jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'),
  limits         jsonb not null default '{}'::jsonb check (jsonb_typeof(limits) = 'object'),
  starts_at      timestamptz,
  ends_at        timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint erp_tenant_capability_period_valid
    check (ends_at is null or starts_at is null or ends_at > starts_at),
  constraint erp_tenant_capability_unique unique (tenant_id, capability_key),
  constraint erp_tenant_capability_tenant_id_unique unique (tenant_id, id)
);

create index erp_tenant_capabilities_status
  on public.erp_tenant_capabilities(tenant_id, status);

create table public.erp_segment_profiles (
  key         text primary key check (key ~ '^[a-z][a-z0-9_.-]{1,63}$'),
  name        text not null,
  description text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.erp_segment_profile_capabilities (
  profile_key    text not null references public.erp_segment_profiles(key) on delete cascade,
  capability_key text not null references public.erp_capability_catalog(key) on delete cascade,
  recommendation text not null default 'recommended'
                 check (recommendation in ('base', 'recommended', 'optional')),
  config          jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'),
  primary key (profile_key, capability_key)
);

create table public.erp_tenant_segment_profiles (
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  profile_key  text not null references public.erp_segment_profiles(key) on delete restrict,
  is_primary   boolean not null default false,
  config       jsonb not null default '{}'::jsonb check (jsonb_typeof(config) = 'object'),
  created_at   timestamptz not null default now(),
  primary key (tenant_id, profile_key)
);

create unique index erp_tenant_profiles_one_primary
  on public.erp_tenant_segment_profiles(tenant_id)
  where is_primary;

-- -----------------------------------------------------------------------------
-- 3. CONFIGURAÇÕES, NUMERAÇÃO E AUDITORIA
-- -----------------------------------------------------------------------------

create table public.erp_tenant_settings (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references public.tenants(id) on delete cascade,
  establishment_id uuid,
  key              text not null check (key ~ '^[a-z][a-z0-9_.-]{1,95}$'),
  value            jsonb not null,
  sensitivity      text not null default 'internal'
                   check (sensitivity in ('public', 'internal')),
  schema_version   integer not null default 1 check (schema_version > 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint erp_tenant_settings_no_secret_keys
    check (key !~* '(secret|password|token|credential|certificate|pfx)'),
  constraint erp_tenant_settings_establishment_fk
    foreign key (tenant_id, establishment_id)
    references public.erp_establishments(tenant_id, id) on delete cascade
);

create unique index erp_tenant_settings_global_unique
  on public.erp_tenant_settings(tenant_id, key)
  where establishment_id is null;
create unique index erp_tenant_settings_establishment_unique
  on public.erp_tenant_settings(tenant_id, establishment_id, key)
  where establishment_id is not null;

create table public.erp_number_sequences (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references public.tenants(id) on delete cascade,
  establishment_id uuid,
  sequence_key     text not null check (sequence_key ~ '^[a-z][a-z0-9_.-]{1,63}$'),
  prefix           text not null default '',
  suffix           text not null default '',
  padding          smallint not null default 6 check (padding between 1 and 18),
  start_value      bigint not null default 1 check (start_value >= 0),
  increment_by     bigint not null default 1 check (increment_by > 0),
  current_value    bigint not null default 0 check (current_value >= 0),
  reset_policy     text not null default 'never'
                   check (reset_policy in ('never', 'year', 'month', 'day')),
  current_period   text not null default '',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint erp_number_sequences_establishment_fk
    foreign key (tenant_id, establishment_id)
    references public.erp_establishments(tenant_id, id) on delete cascade,
  constraint erp_number_sequences_scope_unique
    unique nulls not distinct (tenant_id, establishment_id, sequence_key),
  constraint erp_number_sequences_tenant_id_unique unique (tenant_id, id)
);

create table public.erp_audit_events (
  id                  bigint generated always as identity primary key,
  tenant_id           uuid not null references public.tenants(id) on delete restrict,
  establishment_id    uuid,
  actor_user_id       uuid references public.users(id) on delete restrict,
  actor_membership_id uuid,
  action              text not null check (length(action) between 3 and 120),
  entity_type         text not null check (length(entity_type) between 2 and 80),
  entity_id           text,
  outcome             text not null default 'success'
                      check (outcome in ('success', 'denied', 'error')),
  request_id          uuid,
  correlation_id      uuid,
  ip_address          inet,
  user_agent          text,
  metadata            jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at          timestamptz not null default now(),
  constraint erp_audit_membership_actor_present
    check (actor_membership_id is null or actor_user_id is not null),
  constraint erp_audit_establishment_fk
    foreign key (tenant_id, establishment_id)
    references public.erp_establishments(tenant_id, id) on delete restrict,
  constraint erp_audit_membership_fk
    foreign key (tenant_id, actor_membership_id, actor_user_id)
    references public.erp_tenant_memberships(tenant_id, id, user_id) on delete restrict
);

create index erp_audit_tenant_created
  on public.erp_audit_events(tenant_id, created_at desc);
create index erp_audit_entity
  on public.erp_audit_events(tenant_id, entity_type, entity_id, created_at desc);
create index erp_audit_actor
  on public.erp_audit_events(actor_user_id, created_at desc)
  where actor_user_id is not null;

-- -----------------------------------------------------------------------------
-- 4. HELPERS PRIVADOS DE RLS E NUMERAÇÃO
-- -----------------------------------------------------------------------------

create or replace function erp_security.is_tenant_member(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.erp_tenant_memberships membership
    join public.users profile on profile.id = membership.user_id
    join public.tenants tenant on tenant.id = membership.tenant_id
    where membership.tenant_id = p_tenant_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and profile.ativo
      and tenant.ativo
      and (membership.starts_at is null or membership.starts_at <= now())
      and (membership.ends_at is null or membership.ends_at > now())
  )
$$;

create or replace function erp_security.has_permission(
  p_tenant_id uuid,
  p_permission_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.erp_tenant_memberships membership
    join public.users profile on profile.id = membership.user_id
    join public.tenants tenant on tenant.id = membership.tenant_id
    join public.erp_membership_roles membership_role
      on membership_role.tenant_id = membership.tenant_id
     and membership_role.membership_id = membership.id
    join public.erp_roles role
      on role.tenant_id = membership_role.tenant_id
     and role.id = membership_role.role_id
     and role.active
    join public.erp_role_permissions role_permission
      on role_permission.tenant_id = membership_role.tenant_id
     and role_permission.role_id = membership_role.role_id
    join public.erp_permissions permission
      on permission.id = role_permission.permission_id
    where membership.tenant_id = p_tenant_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and profile.ativo
      and tenant.ativo
      and permission.key = p_permission_key
      and permission.active
      and (membership.starts_at is null or membership.starts_at <= now())
      and (membership.ends_at is null or membership.ends_at > now())
  )
$$;

create or replace function erp_security.next_number(
  p_tenant_id uuid,
  p_sequence_key text,
  p_establishment_id uuid default null,
  p_operation_date date default current_date
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  sequence_row public.erp_number_sequences%rowtype;
  expected_period text;
  next_value bigint;
begin
  select *
    into sequence_row
  from public.erp_number_sequences
  where tenant_id = p_tenant_id
    and establishment_id is not distinct from p_establishment_id
    and sequence_key = p_sequence_key
  for update;

  if not found then
    raise exception 'ERP_SEQUENCE_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  expected_period := case sequence_row.reset_policy
    when 'year' then to_char(p_operation_date, 'YYYY')
    when 'month' then to_char(p_operation_date, 'YYYYMM')
    when 'day' then to_char(p_operation_date, 'YYYYMMDD')
    else ''
  end;

  if sequence_row.current_period is distinct from expected_period then
    next_value := sequence_row.start_value;
  elsif sequence_row.current_value = 0 then
    next_value := sequence_row.start_value;
  else
    next_value := sequence_row.current_value + sequence_row.increment_by;
  end if;

  update public.erp_number_sequences
  set current_value = next_value,
      current_period = expected_period,
      updated_at = now()
  where id = sequence_row.id;

  return sequence_row.prefix
      || lpad(next_value::text, sequence_row.padding, '0')
      || sequence_row.suffix;
end;
$$;

create or replace function public.erp_next_number(
  p_tenant_id uuid,
  p_sequence_key text,
  p_establishment_id uuid default null,
  p_operation_date date default current_date
)
returns text
language sql
security invoker
set search_path = ''
as $$
  select erp_security.next_number(
    p_tenant_id,
    p_sequence_key,
    p_establishment_id,
    p_operation_date
  )
$$;

create or replace function erp_security.prevent_audit_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'ERP_AUDIT_EVENTS_APPEND_ONLY'
    using errcode = '55000';
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. TRIGGERS
-- -----------------------------------------------------------------------------

create trigger trg_erp_memberships_updated_at
  before update on public.erp_tenant_memberships
  for each row execute function public.set_updated_at();
create trigger trg_erp_roles_updated_at
  before update on public.erp_roles
  for each row execute function public.set_updated_at();
create trigger trg_erp_establishments_updated_at
  before update on public.erp_establishments
  for each row execute function public.set_updated_at();
create trigger trg_erp_capability_catalog_updated_at
  before update on public.erp_capability_catalog
  for each row execute function public.set_updated_at();
create trigger trg_erp_tenant_capabilities_updated_at
  before update on public.erp_tenant_capabilities
  for each row execute function public.set_updated_at();
create trigger trg_erp_segment_profiles_updated_at
  before update on public.erp_segment_profiles
  for each row execute function public.set_updated_at();
create trigger trg_erp_tenant_settings_updated_at
  before update on public.erp_tenant_settings
  for each row execute function public.set_updated_at();
create trigger trg_erp_number_sequences_updated_at
  before update on public.erp_number_sequences
  for each row execute function public.set_updated_at();
create trigger trg_erp_audit_append_only
  before update or delete on public.erp_audit_events
  for each row execute function erp_security.prevent_audit_mutation();

-- -----------------------------------------------------------------------------
-- 6. CATÁLOGOS GLOBAIS (SEM DADOS DE CLIENTE)
-- -----------------------------------------------------------------------------

insert into public.erp_permissions (key, name, description, category)
values
  ('foundation.read', 'Consultar fundação', 'Consulta dados organizacionais e capacidades.', 'foundation'),
  ('foundation.manage', 'Gerenciar fundação', 'Gerencia estabelecimentos e configurações.', 'foundation'),
  ('memberships.read', 'Consultar membros', 'Consulta memberships e seus papéis.', 'identity'),
  ('memberships.manage', 'Gerenciar membros', 'Convida, suspende e revoga memberships.', 'identity'),
  ('roles.manage', 'Gerenciar papéis', 'Gerencia papéis e permissões do tenant.', 'identity'),
  ('capabilities.manage', 'Gerenciar capacidades', 'Habilita e suspende capacidades.', 'foundation'),
  ('sequences.allocate', 'Consumir numeração', 'Obtém o próximo número de uma sequência.', 'foundation'),
  ('audit.read', 'Consultar auditoria', 'Consulta eventos de auditoria do tenant.', 'audit')
on conflict (key) do nothing;

insert into public.erp_capability_catalog (key, name, description, category)
values
  ('core.organization', 'Organização', 'Tenant, estabelecimentos e parâmetros operacionais.', 'core'),
  ('core.parties', 'Pessoas e organizações', 'Clientes, fornecedores, colaboradores e contatos.', 'core'),
  ('core.catalog', 'Catálogo universal', 'Produtos, serviços, peças, ingredientes e kits.', 'core'),
  ('catalog.variants', 'Variações e atributos', 'Cor, tamanho, material e outras variações controladas.', 'catalog'),
  ('core.pricing', 'Preços', 'Listas, vigências, promoções e regras de preço.', 'core'),
  ('inventory.stock', 'Estoque', 'Locais, movimentos, reservas e inventários.', 'inventory'),
  ('inventory.lots', 'Lotes e validade', 'Controle de lotes, fabricação e validade.', 'inventory'),
  ('inventory.serials', 'Números de série', 'Rastreio unitário de itens serializados.', 'inventory'),
  ('procurement', 'Compras', 'Pedidos e recebimentos de compra.', 'procurement'),
  ('sales.quotes', 'Orçamentos', 'Propostas e conversão em pedido.', 'sales'),
  ('sales.orders', 'Pedidos e vendas', 'Pedidos, vendas, devoluções e recebimentos.', 'sales'),
  ('sales.pos', 'PDV e caixa', 'Frente de caixa, sessões e movimentos.', 'sales'),
  ('finance', 'Financeiro', 'Títulos, parcelas, liquidações e bancos.', 'finance'),
  ('service.orders', 'Ordens de serviço', 'Serviços, peças, mão de obra e eventos.', 'service'),
  ('service.assets', 'Ativos e equipamentos', 'Equipamentos mantidos e histórico técnico.', 'service'),
  ('workshop.vehicles', 'Veículos', 'Cadastro veicular e aplicação em oficina.', 'workshop'),
  ('food.compositions', 'Receitas e composições', 'Fichas técnicas, ingredientes e rendimento.', 'food'),
  ('food.table_service', 'Mesas e comandas', 'Salão, mesas, comandas e adicionais.', 'food'),
  ('food.kitchen', 'Produção de cozinha', 'Fila e estados de preparação.', 'food'),
  ('support.tickets', 'Atendimento', 'Tickets, eventos e SLA.', 'support'),
  ('support.remote', 'Acesso remoto', 'Dispositivos, consentimentos e sessões.', 'support'),
  ('fiscal', 'Fiscal', 'Perfis tributários, DF-e e eventos.', 'fiscal'),
  ('migration', 'Migração', 'Lotes, mapas de ID, erros e reconciliação.', 'migration')
on conflict (key) do nothing;

insert into public.erp_segment_profiles (key, name, description)
values
  ('retail_general', 'Varejo geral', 'Comércio varejista com catálogo, estoque, compras, vendas e caixa.'),
  ('apparel_stationery', 'Vestuário, papelaria e variedades', 'Varejo com atributos, variações, etiquetas e unidades flexíveis.'),
  ('workshop', 'Oficina e manutenção', 'Peças, serviços, veículos/equipamentos e ordens de serviço.'),
  ('food_service', 'Restaurante e lanchonete', 'Ingredientes, receitas, comandas, produção e PDV.'),
  ('professional_services', 'Prestação de serviços', 'Agenda, serviços, contratos, financeiro e atendimento.')
on conflict (key) do nothing;

insert into public.erp_segment_profile_capabilities
  (profile_key, capability_key, recommendation)
values
  ('retail_general', 'core.organization', 'base'),
  ('retail_general', 'core.parties', 'base'),
  ('retail_general', 'core.catalog', 'base'),
  ('retail_general', 'core.pricing', 'base'),
  ('retail_general', 'inventory.stock', 'recommended'),
  ('retail_general', 'procurement', 'recommended'),
  ('retail_general', 'sales.quotes', 'optional'),
  ('retail_general', 'sales.orders', 'recommended'),
  ('retail_general', 'sales.pos', 'recommended'),
  ('retail_general', 'finance', 'base'),
  ('retail_general', 'fiscal', 'recommended'),

  ('apparel_stationery', 'core.organization', 'base'),
  ('apparel_stationery', 'core.parties', 'base'),
  ('apparel_stationery', 'core.catalog', 'base'),
  ('apparel_stationery', 'catalog.variants', 'recommended'),
  ('apparel_stationery', 'core.pricing', 'base'),
  ('apparel_stationery', 'inventory.stock', 'recommended'),
  ('apparel_stationery', 'procurement', 'recommended'),
  ('apparel_stationery', 'sales.orders', 'recommended'),
  ('apparel_stationery', 'sales.pos', 'recommended'),
  ('apparel_stationery', 'finance', 'base'),
  ('apparel_stationery', 'fiscal', 'recommended'),

  ('workshop', 'core.organization', 'base'),
  ('workshop', 'core.parties', 'base'),
  ('workshop', 'core.catalog', 'base'),
  ('workshop', 'core.pricing', 'base'),
  ('workshop', 'inventory.stock', 'recommended'),
  ('workshop', 'procurement', 'recommended'),
  ('workshop', 'sales.quotes', 'recommended'),
  ('workshop', 'sales.orders', 'recommended'),
  ('workshop', 'finance', 'base'),
  ('workshop', 'service.orders', 'recommended'),
  ('workshop', 'service.assets', 'optional'),
  ('workshop', 'workshop.vehicles', 'recommended'),
  ('workshop', 'fiscal', 'recommended'),

  ('food_service', 'core.organization', 'base'),
  ('food_service', 'core.parties', 'base'),
  ('food_service', 'core.catalog', 'base'),
  ('food_service', 'core.pricing', 'base'),
  ('food_service', 'inventory.stock', 'recommended'),
  ('food_service', 'inventory.lots', 'recommended'),
  ('food_service', 'procurement', 'recommended'),
  ('food_service', 'sales.orders', 'recommended'),
  ('food_service', 'sales.pos', 'recommended'),
  ('food_service', 'finance', 'base'),
  ('food_service', 'food.compositions', 'recommended'),
  ('food_service', 'food.table_service', 'recommended'),
  ('food_service', 'food.kitchen', 'recommended'),
  ('food_service', 'fiscal', 'recommended'),

  ('professional_services', 'core.organization', 'base'),
  ('professional_services', 'core.parties', 'base'),
  ('professional_services', 'core.catalog', 'base'),
  ('professional_services', 'core.pricing', 'base'),
  ('professional_services', 'sales.quotes', 'recommended'),
  ('professional_services', 'sales.orders', 'recommended'),
  ('professional_services', 'finance', 'base'),
  ('professional_services', 'service.orders', 'recommended'),
  ('professional_services', 'service.assets', 'optional'),
  ('professional_services', 'support.tickets', 'optional'),
  ('professional_services', 'fiscal', 'optional')
on conflict (profile_key, capability_key) do nothing;

-- -----------------------------------------------------------------------------
-- 7. RLS
-- -----------------------------------------------------------------------------

alter table public.erp_tenant_memberships enable row level security;
alter table public.erp_roles enable row level security;
alter table public.erp_permissions enable row level security;
alter table public.erp_role_permissions enable row level security;
alter table public.erp_membership_roles enable row level security;
alter table public.erp_establishments enable row level security;
alter table public.erp_capability_catalog enable row level security;
alter table public.erp_tenant_capabilities enable row level security;
alter table public.erp_segment_profiles enable row level security;
alter table public.erp_segment_profile_capabilities enable row level security;
alter table public.erp_tenant_segment_profiles enable row level security;
alter table public.erp_tenant_settings enable row level security;
alter table public.erp_number_sequences enable row level security;
alter table public.erp_audit_events enable row level security;

create policy erp_memberships_select_self_or_staff
  on public.erp_tenant_memberships for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_platform_staff()));

create policy erp_roles_select_member_or_staff
  on public.erp_roles for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_permissions_select_authenticated
  on public.erp_permissions for select to authenticated using (true);

create policy erp_role_permissions_select_member_or_staff
  on public.erp_role_permissions for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_membership_roles_select_self_or_staff
  on public.erp_membership_roles for select to authenticated
  using (
    exists (
      select 1
      from public.erp_tenant_memberships membership
      where membership.tenant_id = erp_membership_roles.tenant_id
        and membership.id = erp_membership_roles.membership_id
        and membership.user_id = (select auth.uid())
    )
    or (select public.is_platform_staff())
  );

create policy erp_establishments_select_member_or_staff
  on public.erp_establishments for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_capabilities_select_authenticated
  on public.erp_capability_catalog for select to authenticated using (true);

create policy erp_tenant_capabilities_select_member_or_staff
  on public.erp_tenant_capabilities for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_segment_profiles_select_authenticated
  on public.erp_segment_profiles for select to authenticated using (true);

create policy erp_segment_profile_capabilities_select_authenticated
  on public.erp_segment_profile_capabilities for select to authenticated using (true);

create policy erp_tenant_profiles_select_member_or_staff
  on public.erp_tenant_segment_profiles for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_tenant_settings_select_member_or_staff
  on public.erp_tenant_settings for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_number_sequences_select_member_or_staff
  on public.erp_number_sequences for select to authenticated
  using (
    (select erp_security.is_tenant_member(tenant_id))
    or (select public.is_platform_staff())
  );

create policy erp_audit_select_actor_permission_or_staff
  on public.erp_audit_events for select to authenticated
  using (
    actor_user_id = (select auth.uid())
    or (select erp_security.has_permission(tenant_id, 'audit.read'))
    or (select public.is_platform_staff())
  );

-- -----------------------------------------------------------------------------
-- 8. GRANTS MÍNIMOS
-- A migration 0008 configura SELECT como default para authenticated. Revogamos
-- tudo explicitamente e devolvemos somente SELECT protegido por RLS.
-- -----------------------------------------------------------------------------

revoke all on table
  public.erp_tenant_memberships,
  public.erp_roles,
  public.erp_permissions,
  public.erp_role_permissions,
  public.erp_membership_roles,
  public.erp_establishments,
  public.erp_capability_catalog,
  public.erp_tenant_capabilities,
  public.erp_segment_profiles,
  public.erp_segment_profile_capabilities,
  public.erp_tenant_segment_profiles,
  public.erp_tenant_settings,
  public.erp_number_sequences,
  public.erp_audit_events
from anon, authenticated;

grant select on table
  public.erp_tenant_memberships,
  public.erp_roles,
  public.erp_permissions,
  public.erp_role_permissions,
  public.erp_membership_roles,
  public.erp_establishments,
  public.erp_capability_catalog,
  public.erp_tenant_capabilities,
  public.erp_segment_profiles,
  public.erp_segment_profile_capabilities,
  public.erp_tenant_segment_profiles,
  public.erp_tenant_settings,
  public.erp_number_sequences,
  public.erp_audit_events
to authenticated;

grant all on table
  public.erp_tenant_memberships,
  public.erp_roles,
  public.erp_permissions,
  public.erp_role_permissions,
  public.erp_membership_roles,
  public.erp_establishments,
  public.erp_capability_catalog,
  public.erp_tenant_capabilities,
  public.erp_segment_profiles,
  public.erp_segment_profile_capabilities,
  public.erp_tenant_segment_profiles,
  public.erp_tenant_settings,
  public.erp_number_sequences,
  public.erp_audit_events
to service_role;

revoke all on all functions in schema erp_security from public, anon, authenticated;
grant execute on function erp_security.is_tenant_member(uuid) to authenticated, service_role;
grant execute on function erp_security.has_permission(uuid, text) to authenticated, service_role;
grant execute on function erp_security.next_number(uuid, text, uuid, date) to service_role;

revoke execute on function public.erp_next_number(uuid, text, uuid, date)
  from public, anon, authenticated;
grant execute on function public.erp_next_number(uuid, text, uuid, date)
  to service_role;

grant usage, select on all sequences in schema public to service_role;

-- -----------------------------------------------------------------------------
-- 9. COMENTÁRIOS OPERACIONAIS
-- -----------------------------------------------------------------------------

comment on schema erp_security is
  'Helpers internos de RLS e domínio. Não expor no Data API.';
comment on table public.erp_tenant_memberships is
  'Associação entre usuário e tenant. Substitui gradualmente a limitação de users.tenant_id único.';
comment on table public.erp_roles is
  'Papéis do ERP definidos por tenant; não confundir com public.roles da equipe/plataforma.';
comment on table public.erp_permissions is
  'Catálogo global de ações autorizáveis do ERP.';
comment on table public.erp_establishments is
  'Lojas, filiais, oficinas, cozinhas e unidades operacionais de um tenant.';
comment on table public.erp_capability_catalog is
  'Capacidades técnicas do ERP; separado do module_catalog comercial da ConnectionCyber.';
comment on table public.erp_tenant_capabilities is
  'Capacidades efetivamente habilitadas em cada tenant.';
comment on table public.erp_segment_profiles is
  'Templates que sugerem capacidades por segmento; nunca concedem autorização.';
comment on table public.erp_tenant_settings is
  'Configurações não secretas, validadas pela aplicação. PFX, tokens e senhas são proibidos.';
comment on table public.erp_number_sequences is
  'Estado de numeração transacional protegido por bloqueio de linha.';
comment on table public.erp_audit_events is
  'Trilha append-only do ERP. Correções são novos eventos, nunca update/delete.';
comment on function erp_security.is_tenant_member(uuid) is
  'Helper privado para RLS: valida membership ativa, usuário ativo e tenant ativo.';
comment on function erp_security.has_permission(uuid, text) is
  'Helper privado para RLS: verifica permissão no tenant sem recursão de policy.';
comment on function public.erp_next_number(uuid, text, uuid, date) is
  'Wrapper server-only para obter número transacional com lock. Sem grant a anon/authenticated.';

commit;
