-- =========================================================================
-- ConnectionCyberSO — Módulo Catálogo de Produtos e Ofertas (IA)
--
-- Origem: adaptado de cc-commerce-studio (features/products, features/offer-engine;
-- supabase/migrations 002 e 004), mesma auditoria de 2026-08-15 do módulo Diagnóstico
-- Digital (0009). Ver docs/migracao-diagnostico-digital-cc-commerce-studio.md para o
-- racional completo da decisão "workspace = tenant, 1 pra 1" e da correção de
-- segurança (tenant sempre derivado da sessão, nunca de FormData) — aplicada aqui
-- do mesmo jeito.
--
-- Escopo deliberadamente reduzido em relação ao original: `brand_id` (FK para
-- `brands`, tabela de marca por produto) NÃO foi trazido nesta rodada — é opcional
-- no código original e nenhum tenant hoje precisa de múltiplas marcas por conta.
-- Fica como próximo incremento, se algum cliente pedir.
--
-- Nomes prefixados com `mpi_` (mesmo padrão de 0009/mpi_projects) para não colidir
-- com o domínio de e-commerce já existente (`products`/`orders` de 0001_init_schema.sql
-- — catálogo próprio da ConnectionCyber, vendido via apps/site).
-- =========================================================================

create table if not exists public.mpi_products (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  name         text not null,
  description  text,
  status       text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.mpi_products is
  'Produto do cliente (tenant) dentro do módulo Catálogo/Ofertas — não é o catálogo de cursos/produtos da própria ConnectionCyber (esse é public.products).';

create index if not exists idx_mpi_products_tenant on public.mpi_products (tenant_id);

create table if not exists public.mpi_offers (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  product_id   uuid not null references public.mpi_products(id) on delete cascade,
  title        text not null,
  copy         text,
  status       text not null default 'draft' check (status in ('draft', 'generated', 'published')),
  prompt_id    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.mpi_offers is
  'Oferta de venda (copy gerada por IA ou manual) vinculada a um mpi_product.';

create index if not exists idx_mpi_offers_tenant  on public.mpi_offers (tenant_id);
create index if not exists idx_mpi_offers_product on public.mpi_offers (product_id);

create trigger trg_mpi_products_updated_at
  before update on public.mpi_products
  for each row execute function public.set_updated_at();

create trigger trg_mpi_offers_updated_at
  before update on public.mpi_offers
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------------------
-- RLS — mesmo padrão de 0009: current_tenant_id() / is_platform_staff().
-- -------------------------------------------------------------------------

alter table public.mpi_products enable row level security;
alter table public.mpi_offers   enable row level security;

create policy "tenant gerencia os próprios produtos"
  on public.mpi_products for all
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê produtos de todos os tenants"
  on public.mpi_products for select
  using (public.is_platform_staff());

create policy "tenant gerencia as próprias ofertas"
  on public.mpi_offers for all
  using (tenant_id = public.current_tenant_id())
  with check (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê ofertas de todos os tenants"
  on public.mpi_offers for select
  using (public.is_platform_staff());

-- -------------------------------------------------------------------------
-- Grants — mesmo padrão de 0008/0009.
-- -------------------------------------------------------------------------

grant insert, update, delete on public.mpi_products to authenticated;
grant insert, update, delete on public.mpi_offers   to authenticated;

-- -------------------------------------------------------------------------
-- Registro no catálogo de módulos.
-- -------------------------------------------------------------------------

insert into public.module_catalog (key, name, description, default_kpis, default_sla)
values (
  'catalogo-produtos-ofertas-ia',
  'Catálogo de Produtos e Ofertas (IA)',
  'Cadastro de produtos do cliente e geração de copy de oferta de venda por IA — segue naturalmente do Diagnóstico Digital.',
  '[{"frente": "Ofertas", "kpi": "Ofertas geradas por tenant"}]'::jsonb,
  '{}'::jsonb
)
on conflict (key) do nothing;
