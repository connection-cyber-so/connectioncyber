-- =========================================================================
-- ConnectionCyberSO — Módulo Diagnóstico Digital (IA)
--
-- Origem: adaptado de cc-commerce-studio (features/diagnostic-engine,
-- supabase/migrations 001 e 007), projeto avaliado em auditoria read-only
-- de J:\BK_connectioncyber\connectioncyber\cc-commerce-studio em 2026-08-15
-- (ver docs/auditoria-backup-jdrive-cc-commerce-studio.md).
--
-- Decisão de 2026-08-15: "workspace = tenant, 1 pra 1". O código original
-- usava `workspaces` + `workspace_members` (tabela de membros N:N, um
-- usuário podia pertencer a vários workspaces). Aqui isso é substituído
-- pelo modelo já existente do projeto — `tenants` + `current_tenant_id()`
-- (lido de public.users, 1 usuário = 1 tenant) — sem tabela de membros
-- nova. Nomes de coluna trocados de workspace_id → tenant_id.
--
-- Renomeado `projects` (nome genérico no original) para `mpi_projects`,
-- para não colidir semanticamente com o domínio de e-commerce já existente
-- (courses/products/orders de 0001_init_schema.sql).
-- =========================================================================

create table if not exists public.mpi_projects (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  name         text not null,
  description  text,
  status       text not null default 'draft' check (status in ('draft', 'in_progress', 'completed')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.mpi_projects is
  'Ciclo/projeto de MPI (Marketing e Posicionamento na Internet) por tenant. Um tenant normalmente tem 1, criado automaticamente pelo Diagnóstico Digital na primeira visita.';

create index if not exists idx_mpi_projects_tenant on public.mpi_projects (tenant_id);

create table if not exists public.mpi_diagnostics (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  project_id   uuid not null references public.mpi_projects(id) on delete cascade,
  title        text not null,
  answers      jsonb not null default '{}'::jsonb,
  summary      text,
  status       text not null default 'draft' check (status in ('draft', 'generated')),
  prompt_id    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.mpi_diagnostics is
  'Diagnóstico de maturidade digital gerado por IA (Gemini) a partir de canais, público-alvo, concorrentes e objetivo do tenant.';

create index if not exists idx_mpi_diagnostics_tenant  on public.mpi_diagnostics (tenant_id);
create index if not exists idx_mpi_diagnostics_project on public.mpi_diagnostics (project_id);

create trigger trg_mpi_projects_updated_at
  before update on public.mpi_projects
  for each row execute function public.set_updated_at();

create trigger trg_mpi_diagnostics_updated_at
  before update on public.mpi_diagnostics
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------------------
-- RLS — reaproveita current_tenant_id() e is_platform_staff() de 0002,
-- em vez do padrão workspace_members do projeto original.
-- -------------------------------------------------------------------------

alter table public.mpi_projects    enable row level security;
alter table public.mpi_diagnostics enable row level security;

create policy "tenant gerencia os próprios projetos MPI"
  on public.mpi_projects for all
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê projetos MPI de todos os tenants"
  on public.mpi_projects for select
  using (public.is_platform_staff());

create policy "tenant gerencia os próprios diagnósticos"
  on public.mpi_diagnostics for all
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê diagnósticos de todos os tenants"
  on public.mpi_diagnostics for select
  using (public.is_platform_staff());

-- -------------------------------------------------------------------------
-- Grants — mesmo padrão de 0008: authenticated só tem SELECT por padrão em
-- todo o schema (default privileges já revogados em 0008); aqui liberamos
-- DML explicitamente porque as duas tabelas acima já têm RLS + policy real.
-- -------------------------------------------------------------------------

grant insert, update, delete on public.mpi_projects    to authenticated;
grant insert, update, delete on public.mpi_diagnostics to authenticated;

-- -------------------------------------------------------------------------
-- Registro no catálogo de módulos (mesmo mecanismo de habilitação por
-- tenant já usado pelos módulos existentes — ver 0004).
-- -------------------------------------------------------------------------

insert into public.module_catalog (key, name, description, default_kpis, default_sla)
values (
  'diagnostico-digital-ia',
  'Diagnóstico Digital (IA)',
  'Diagnóstico de maturidade digital gerado por IA a partir de canais digitais, público-alvo, concorrentes e objetivo do cliente — recomenda o próximo serviço a contratar.',
  '[{"frente": "Diagnóstico", "kpi": "Diagnósticos gerados por tenant"}]'::jsonb,
  '{}'::jsonb
)
on conflict (key) do nothing;
