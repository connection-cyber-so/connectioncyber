-- =========================================================================
-- ConnectionCyberSO — Módulo Roteiro de Vídeo (IA)
--
-- Origem: adaptado de cc-commerce-studio (features/video-script-engine;
-- supabase/migrations 006), mesma auditoria de 2026-08-15. Terceiro módulo
-- migrado desta linhagem — ver docs/migracao-diagnostico-digital-cc-commerce-studio.md
-- para o racional completo ("workspace = tenant", correção de segurança).
--
-- Depende de mpi_offers (0010) — um roteiro de vídeo parte da copy de uma
-- oferta já existente, mesma relação do original (video_scripts.offer_id).
-- =========================================================================

create table if not exists public.mpi_video_scripts (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  offer_id     uuid not null references public.mpi_offers(id) on delete cascade,
  title        text not null,
  script       text,
  status       text not null default 'draft' check (status in ('draft', 'generated')),
  prompt_id    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.mpi_video_scripts is
  'Roteiro de vídeo de venda (estilo VSL, gerado por IA ou manual) a partir de uma mpi_offer.';

create index if not exists idx_mpi_video_scripts_tenant on public.mpi_video_scripts (tenant_id);
create index if not exists idx_mpi_video_scripts_offer  on public.mpi_video_scripts (offer_id);

create trigger trg_mpi_video_scripts_updated_at
  before update on public.mpi_video_scripts
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------------------
-- RLS — mesmo padrão de 0009/0010.
-- -------------------------------------------------------------------------

alter table public.mpi_video_scripts enable row level security;

create policy "tenant gerencia os próprios roteiros de vídeo"
  on public.mpi_video_scripts for all
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê roteiros de vídeo de todos os tenants"
  on public.mpi_video_scripts for select
  using (public.is_platform_staff());

-- -------------------------------------------------------------------------
-- Grants — mesmo padrão de 0008/0009/0010.
-- -------------------------------------------------------------------------

grant insert, update, delete on public.mpi_video_scripts to authenticated;

-- -------------------------------------------------------------------------
-- Registro no catálogo de módulos.
-- -------------------------------------------------------------------------

insert into public.module_catalog (key, name, description, default_kpis, default_sla)
values (
  'roteiro-video-ia',
  'Roteiro de Vídeo (IA)',
  'Roteiro de vídeo de venda (estilo VSL: Gancho, Problema, Solução, Prova, Chamada para ação) gerado por IA a partir de uma oferta existente.',
  '[{"frente": "Roteiros", "kpi": "Roteiros gerados por tenant"}]'::jsonb,
  '{}'::jsonb
)
on conflict (key) do nothing;
