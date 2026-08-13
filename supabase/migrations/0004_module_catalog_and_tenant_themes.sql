-- =========================================================================
-- ConnectionCyberSO — Padrões trazidos da auditoria multi-projeto
-- (docs/auditoria-ecossistema-connectioncyberos.md, itens 4 e 6)
--
-- Catálogo de módulos compartilhado + habilitação por tenant: é a peça de
-- banco que sustenta a decisão já tomada (Opção A, Parecer técnico #001) —
-- uma rotina/módulo entra uma vez no catálogo, cada tenant liga/desliga
-- individualmente, sem duplicar código nem schema por cliente.
--
-- tenant_themes: identidade visual por tenant (cor, logo, fonte) — peça que
-- faltava para "particularidade de cliente" que não seja regra de negócio.
-- =========================================================================

-- -------------------------------------------------------------------------
-- Catálogo de módulos (compartilhado — não pertence a nenhum tenant)
-- -------------------------------------------------------------------------

create table if not exists public.module_catalog (
  id            uuid primary key default gen_random_uuid(),
  key           text unique not null,
  name          text not null,
  description   text,
  default_kpis  jsonb,
  default_sla   jsonb,
  created_at    timestamptz not null default now()
);

comment on table public.module_catalog is
  'Catálogo global de módulos/rotinas oferecidos pela plataforma. Cliente novo não duplica isso — só ganha uma linha em tenant_modules apontando pra cá.';

-- -------------------------------------------------------------------------
-- Habilitação de módulo por tenant (ciclo de vida comercial/operacional)
-- -------------------------------------------------------------------------

create table if not exists public.tenant_modules (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  module_key   text not null references public.module_catalog(key) on delete restrict,
  status       text not null default 'diagnosticado'
               check (status in ('diagnosticado', 'proposto', 'ativo', 'suspenso', 'encerrado')),
  kpis         jsonb, -- override do default_kpis do catálogo, quando o tenant negocia algo diferente
  sla          jsonb, -- override do default_sla do catálogo
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (tenant_id, module_key)
);

comment on table public.tenant_modules is
  'Habilitação de cada módulo por tenant. Trocar o status aqui é o equivalente a uma feature flag por cliente — não exige deploy nem migration nova.';

create index if not exists idx_tenant_modules_tenant on public.tenant_modules (tenant_id);
create index if not exists idx_tenant_modules_status on public.tenant_modules (status);

create trigger trg_tenant_modules_updated_at
  before update on public.tenant_modules
  for each row execute function public.set_updated_at();

-- -------------------------------------------------------------------------
-- Identidade visual por tenant
-- -------------------------------------------------------------------------

create table if not exists public.tenant_themes (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null unique references public.tenants(id) on delete cascade,
  primary_color    text,
  secondary_color  text,
  logo_url         text,
  font_family      text,
  created_at       timestamptz not null default now()
);

comment on table public.tenant_themes is
  'Branding por tenant (cor, logo, fonte) — usado quando um cliente precisa do portal com a cara dele, sem fork de código.';

create index if not exists idx_tenant_themes_tenant on public.tenant_themes (tenant_id);

-- -------------------------------------------------------------------------
-- RLS
-- -------------------------------------------------------------------------

alter table public.module_catalog enable row level security;
alter table public.tenant_modules enable row level security;
alter table public.tenant_themes  enable row level security;

-- Catálogo é compartilhado e não-sensível: qualquer usuário autenticado pode ler.
create policy "usuários autenticados leem o catálogo de módulos"
  on public.module_catalog for select
  to authenticated
  using (true);

create policy "usuário vê os módulos do próprio tenant"
  on public.tenant_modules for select
  using (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê módulos de todos os tenants"
  on public.tenant_modules for select
  using (public.is_platform_staff());

create policy "usuário vê o tema do próprio tenant"
  on public.tenant_themes for select
  using (tenant_id = public.current_tenant_id());

create policy "equipe ConnectionCyber vê temas de todos os tenants"
  on public.tenant_themes for select
  using (public.is_platform_staff());

-- -------------------------------------------------------------------------
-- Seed inicial — módulos que a ConnectionCyber já oferece hoje (site atual)
-- -------------------------------------------------------------------------

insert into public.module_catalog (key, name, description, default_kpis, default_sla)
values
(
  'desenvolvimento-sistemas',
  'Desenvolvimento de Sistemas',
  'Sistemas web, aplicativos, portais corporativos e integrações sob medida.',
  '[{"frente": "Entrega de projeto", "kpi": "Prazo de entrega vs. cronograma acordado"}]'::jsonb,
  '{"resposta_horas": 24}'::jsonb
),
(
  'assessoria-tecnica',
  'Assessoria Técnica',
  'Consultoria em TI, planejamento tecnológico, auditoria de sistemas e acompanhamento contínuo.',
  '[{"frente": "Consultoria", "kpi": "Tempo médio de resposta a solicitações"}]'::jsonb,
  '{"resposta_horas": 24}'::jsonb
),
(
  'treinamento-tecnologico',
  'Treinamento Tecnológico',
  'Cursos, workshops e capacitação técnica presencial, online ou híbrida.',
  '[{"frente": "Capacitação", "kpi": "Taxa de conclusão de turma"}]'::jsonb,
  '{}'::jsonb
),
(
  'suporte-global',
  'Suporte Tecnológico Global',
  'Atendimento contínuo, manutenção e monitoramento de sistemas, redes e plataformas.',
  '[{"frente": "Suporte", "kpi": "Tempo médio de primeira resposta"}]'::jsonb,
  '{"primeira_resposta_horas": 4}'::jsonb
)
on conflict (key) do nothing;

-- ConnectionCyber (tenant #1) já opera todos os módulos próprios, ativos.
insert into public.tenant_modules (tenant_id, module_key, status)
select t.id, mc.key, 'ativo'
from public.tenants t
cross join public.module_catalog mc
where t.slug = 'connectioncyber'
on conflict (tenant_id, module_key) do nothing;
