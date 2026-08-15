-- =========================================================================
-- ConnectionCyberSO — Módulo Landing Pages
--
-- Origem: adaptado de cc-commerce-studio (features/landing-pages;
-- supabase/migrations 005), mesma auditoria de 2026-08-15. Quarto módulo
-- migrado — ver docs/migracao-diagnostico-digital-cc-commerce-studio.md.
--
-- Decisão de arquitetura de 2026-08-15 (decidida com Joaquim, ver conversa):
-- a página PUBLICADA é servida por apps/site (já é 100% público, já é o
-- que os clientes finais acessam) — apps/platform continua exclusivamente
-- interno, sem nenhuma rota sem login. A equipe cria/edita a landing page
-- em apps/platform; o lead que clica no anúncio vê a página em apps/site.
--
-- slug: mantido ÚNICO GLOBAL (igual ao original), e não por tenant. Na
-- primeira avaliação isso parecia um bug (dois tenants concorrendo pelo
-- mesmo slug) — mas é o comportamento correto aqui: é um namespace
-- compartilhado sob o domínio da própria ConnectionCyber
-- (connectioncyber.com.br/lp/<slug>), o mesmo modelo de qualquer
-- construtor de landing page (Lead Pages, Unbounce, Carrd) — não uma
-- URL por cliente.
-- =========================================================================

create table if not exists public.mpi_landing_pages (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  offer_id     uuid not null references public.mpi_offers(id) on delete cascade,
  title        text not null,
  slug         text not null unique,
  content      text,
  status       text not null default 'draft' check (status in ('draft', 'published')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.mpi_landing_pages is
  'Landing page pública a partir de uma mpi_offer. Servida ao público via apps/site (/lp/[slug]), nunca via apps/platform.';

create index if not exists idx_mpi_landing_pages_tenant on public.mpi_landing_pages (tenant_id);
create index if not exists idx_mpi_landing_pages_offer  on public.mpi_landing_pages (offer_id);
-- slug já indexado pela constraint unique acima — é o caminho de leitura da rota pública.

create trigger trg_mpi_landing_pages_updated_at
  before update on public.mpi_landing_pages
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------------------
-- RLS
-- -------------------------------------------------------------------------

alter table public.mpi_landing_pages enable row level security;

create policy "tenant gerencia as próprias landing pages"
  on public.mpi_landing_pages for all
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê landing pages de todos os tenants"
  on public.mpi_landing_pages for select
  using (public.is_platform_staff());

-- Acesso público (sem sessão): só a página publicada, e nada além do que
-- já é intencionalmente público (título, slug, conteúdo de marketing).
-- Não depende de auth.uid() — funciona pela chave anônima do apps/site.
create policy "público vê landing pages publicadas"
  on public.mpi_landing_pages for select
  using (status = 'published');

-- -------------------------------------------------------------------------
-- Grants
-- -------------------------------------------------------------------------

grant insert, update, delete on public.mpi_landing_pages to authenticated;

-- Primeira tabela do projeto com leitura pública real: apps/site consulta
-- sem sessão nenhuma (role anon do Supabase). Escopo estritamente limitado
-- pela RLS acima (só status = 'published').
grant select on public.mpi_landing_pages to anon;

-- -------------------------------------------------------------------------
-- Registro no catálogo de módulos.
-- -------------------------------------------------------------------------

insert into public.module_catalog (key, name, description, default_kpis, default_sla)
values (
  'landing-pages',
  'Landing Pages',
  'Página de venda pública, publicada em connectioncyber.com.br/lp/<slug>, a partir de uma oferta existente.',
  '[{"frente": "Landing pages", "kpi": "Páginas publicadas por tenant"}]'::jsonb,
  '{}'::jsonb
)
on conflict (key) do nothing;
