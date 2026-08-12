-- =========================================================================
-- ConnectionCyberSO — Multi-tenant (Opção A: plataforma única)
-- Ver Parecer técnico #001, seções 02, 04 e 05.
--
-- Introduz a tabela `tenants` — cada cliente da ConnectionCyberSO (incluindo
-- a própria ConnectionCyber) é uma linha aqui, não um banco/projeto novo.
-- Retrofita tenant_id nas tabelas já conectadas a código real hoje
-- (users, enrollments, orders) e nas tabelas administrativas/auditoria
-- (contact_messages, logs_access, analytics_events, remote_clients).
--
-- Escopo deliberadamente NÃO inclui courses/products/quizzes/exams/trails/
-- cms_content: hoje representam o catálogo próprio da ConnectionCyber
-- (vendido via apps/site). Se cada tenant (ex: Mania de Modas) precisar de
-- catálogo de produtos próprio dentro do ERP, isso é decisão de modelagem
-- de apps/platform — não algo para assumir numa migration de fundação.
--
-- Todas as tabelas afetadas estavam vazias (0 linhas) no momento desta
-- migration — por isso é seguro tornar tenant_id NOT NULL diretamente,
-- sem etapa de backfill.
-- =========================================================================

create table if not exists public.tenants (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  slug        text unique not null,
  vertical    text,                 -- ex: 'assessoria-treinamento', 'varejo', 'food'
  dominio     text,                 -- domínio/subdomínio próprio, se houver
  ativo       boolean not null default true,
  created_at  timestamptz not null default now()
);

comment on table public.tenants is
  'Cada cliente da ConnectionCyberSO. Cliente novo = nova linha aqui, não novo projeto/repositório/banco.';

-- ConnectionCyber é o tenant #1 — todo usuário/admin da própria empresa precisa de um lar aqui.
insert into public.tenants (nome, slug, vertical)
values ('ConnectionCyber', 'connectioncyber', 'assessoria-treinamento')
on conflict (slug) do nothing;

-- -------------------------------------------------------------------------
-- tenant_id nas tabelas já conectadas a código real
-- (precisa vir ANTES das funções abaixo: funções `language sql` são
-- validadas contra o catálogo já na criação, não só na primeira chamada.)
-- -------------------------------------------------------------------------

alter table public.users       add column if not exists tenant_id uuid references public.tenants(id);
alter table public.enrollments add column if not exists tenant_id uuid references public.tenants(id);
alter table public.orders      add column if not exists tenant_id uuid references public.tenants(id);

alter table public.users       alter column tenant_id set not null;
alter table public.enrollments alter column tenant_id set not null;
alter table public.orders      alter column tenant_id set not null;

create index if not exists idx_users_tenant       on public.users (tenant_id);
create index if not exists idx_enrollments_tenant on public.enrollments (tenant_id);
create index if not exists idx_orders_tenant      on public.orders (tenant_id);

-- tenant_id nas tabelas administrativas/auditoria (acesso hoje é só via
-- service role — nullable, sem pressa de NOT NULL enquanto não há UI admin).
alter table public.contact_messages add column if not exists tenant_id uuid references public.tenants(id);
alter table public.logs_access      add column if not exists tenant_id uuid references public.tenants(id);
alter table public.analytics_events add column if not exists tenant_id uuid references public.tenants(id);
alter table public.remote_clients   add column if not exists tenant_id uuid references public.tenants(id);

-- -------------------------------------------------------------------------
-- Helpers de RLS
-- -------------------------------------------------------------------------

create or replace function public.current_tenant_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select tenant_id from public.users where id = auth.uid()
$$;

comment on function public.current_tenant_id() is
  'Tenant do usuário autenticado. Usar nas policies de RLS em vez de repetir a subquery.';

create or replace function public.is_platform_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.nome in ('admin', 'suporte')
  )
$$;

comment on function public.is_platform_staff() is
  'Equipe ConnectionCyber (admin/suporte) — acesso cross-tenant. Todo uso deve ficar em logs_access/remote_logs (modo "quebra-vidro"), ver Parecer técnico #001 seção 05.';

-- -------------------------------------------------------------------------
-- RLS — tenants
-- -------------------------------------------------------------------------

alter table public.tenants enable row level security;

create policy "usuário vê o próprio tenant"
  on public.tenants for select
  using (id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê todos os tenants"
  on public.tenants for select
  using (public.is_platform_staff());

-- -------------------------------------------------------------------------
-- RLS — visão administrativa cross-tenant (ADITIVA)
-- Não remove nem substitui as policies de dono-da-linha já criadas em
-- 0001_init_schema.sql (auth.uid() = user_id) — apenas soma a visão da
-- equipe ConnectionCyber sobre todos os tenants.
-- -------------------------------------------------------------------------

create policy "equipe ConnectionCyber vê todas as matrículas"
  on public.enrollments for select
  using (public.is_platform_staff());

create policy "equipe ConnectionCyber vê todos os pedidos"
  on public.orders for select
  using (public.is_platform_staff());
