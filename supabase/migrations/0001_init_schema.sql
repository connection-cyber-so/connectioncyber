-- =========================================================================
-- ConnectionCyber — Schema inicial (Supabase / PostgreSQL)
-- Unifica os módulos descritos em "prompt geral.txt": site institucional,
-- pagamentos, área de membros estilo Netflix, quizzes, simulados/provas,
-- trilhas, CMS, analytics e módulo de acesso remoto para manutenção de
-- clientes. Os clusters Varejo e Food (seções 16-17) ficam no final,
-- desabilitados por padrão — descomente quando forem ativados.
--
-- Como aplicar:
--   supabase db push
--   -- ou, via MCP: apply_migration com este conteúdo
-- =========================================================================

create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- -------------------------------------------------------------------------
-- 1. IDENTIDADE E ACESSO (RBAC)
-- -------------------------------------------------------------------------

create table if not exists public.roles (
  id          uuid primary key default gen_random_uuid(),
  nome        text unique not null, -- admin | instrutor | aluno | cliente | suporte | tecnico | visitante
  descricao   text,
  created_at  timestamptz not null default now()
);

-- Perfil estendido do usuário autenticado (auth.users é gerenciado pelo Supabase Auth).
create table if not exists public.users (
  id               uuid primary key references auth.users (id) on delete cascade,
  nome             text not null,
  email            text unique not null,
  idioma_preferido text not null default 'pt-BR',
  ativo            boolean not null default true,
  foto_url         text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table if not exists public.user_roles (
  user_id  uuid not null references public.users (id) on delete cascade,
  role_id  uuid not null references public.roles (id) on delete cascade,
  primary key (user_id, role_id)
);

create table if not exists public.logs_access (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.users (id) on delete set null,
  rota        text not null,
  ip          text,
  user_agent  text,
  timestamp   timestamptz not null default now()
);
create index if not exists idx_logs_access_user on public.logs_access (user_id);
create index if not exists idx_logs_access_timestamp on public.logs_access (timestamp desc);

create table if not exists public.system_settings (
  chave        text primary key,
  valor        jsonb not null,
  updated_at   timestamptz not null default now()
);

create table if not exists public.contact_messages (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  email       text not null,
  telefone    text,
  empresa     text,
  mensagem    text not null,
  status      text not null default 'novo', -- novo | em_atendimento | resolvido
  created_at  timestamptz not null default now()
);

-- -------------------------------------------------------------------------
-- 2. CURSOS, MATRÍCULAS E ÁREA DE MEMBROS
-- -------------------------------------------------------------------------

create table if not exists public.courses (
  id          uuid primary key default gen_random_uuid(),
  titulo      text not null,
  descricao   text,
  categoria   text,
  preco       numeric(10, 2) not null default 0,
  status      text not null default 'rascunho', -- rascunho | publicado | arquivado
  idioma      text not null default 'pt-BR',
  capa_url    text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.enrollments (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users (id) on delete cascade,
  course_id       uuid not null references public.courses (id) on delete cascade,
  status          text not null default 'ativa', -- ativa | concluida | cancelada
  progresso       numeric(5, 2) not null default 0, -- 0-100
  data_inscricao  timestamptz not null default now(),
  unique (user_id, course_id)
);
create index if not exists idx_enrollments_user on public.enrollments (user_id);

create table if not exists public.trails (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid references public.courses (id) on delete cascade,
  titulo      text not null,
  descricao   text,
  ordem       integer not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.trail_steps (
  id          uuid primary key default gen_random_uuid(),
  trail_id    uuid not null references public.trails (id) on delete cascade,
  titulo      text not null,
  tipo        text not null default 'video', -- video | pdf | quiz | prova | texto
  conteudo_ref text, -- caminho no Supabase Storage ou URL externa
  ordem       integer not null default 0,
  obrigatorio boolean not null default true
);

-- -------------------------------------------------------------------------
-- 3. QUIZZES, SIMULADOS E PROVAS
-- -------------------------------------------------------------------------

create table if not exists public.quizzes (
  id          uuid primary key default gen_random_uuid(),
  trail_id    uuid references public.trails (id) on delete cascade,
  titulo      text not null,
  publicado   boolean not null default false,
  created_at  timestamptz not null default now()
);

create table if not exists public.quiz_questions (
  id          uuid primary key default gen_random_uuid(),
  quiz_id     uuid not null references public.quizzes (id) on delete cascade,
  enunciado   text not null,
  tipo        text not null default 'multipla_escolha', -- multipla_escolha | verdadeiro_falso | arrastar_soltar
  imagem_url  text,
  video_url   text,
  ordem       integer not null default 0
);

create table if not exists public.quiz_answers (
  id           uuid primary key default gen_random_uuid(),
  question_id  uuid not null references public.quiz_questions (id) on delete cascade,
  texto        text not null,
  correta      boolean not null default false
);

create table if not exists public.exams (
  id            uuid primary key default gen_random_uuid(),
  course_id     uuid references public.courses (id) on delete cascade,
  titulo        text not null,
  tempo_limite_min integer,
  aprovacao_percentual numeric(5,2) not null default 70,
  created_at    timestamptz not null default now()
);

create table if not exists public.exam_questions (
  id          uuid primary key default gen_random_uuid(),
  exam_id     uuid not null references public.exams (id) on delete cascade,
  enunciado   text not null,
  peso        numeric(5,2) not null default 1,
  ordem       integer not null default 0
);

create table if not exists public.exam_results (
  id          uuid primary key default gen_random_uuid(),
  exam_id     uuid not null references public.exams (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  nota        numeric(5,2) not null,
  aprovado    boolean not null,
  respostas   jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists idx_exam_results_user on public.exam_results (user_id);

-- -------------------------------------------------------------------------
-- 4. PRODUTOS, PEDIDOS E PAGAMENTOS (Mercado Pago)
-- -------------------------------------------------------------------------

create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  tipo        text not null default 'fisico', -- fisico | digital
  preco       numeric(10, 2) not null default 0,
  estoque     integer, -- null = ilimitado (produto digital)
  status      text not null default 'ativo', -- ativo | inativo
  created_at  timestamptz not null default now()
);

create table if not exists public.orders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.users (id) on delete set null,
  total       numeric(10, 2) not null default 0,
  status      text not null default 'pendente', -- pendente | pago | recusado | cancelado
  created_at  timestamptz not null default now()
);

create table if not exists public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders (id) on delete cascade,
  product_id      text not null, -- pode referenciar products.id ou courses.id
  quantidade      integer not null default 1,
  preco_unitario  numeric(10, 2) not null default 0
);
create index if not exists idx_order_items_order on public.order_items (order_id);

create table if not exists public.payments (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders (id) on delete cascade,
  gateway         text not null default 'mercado_pago',
  status          text not null, -- approved | pending | rejected | in_process | refunded
  transaction_id  text,
  payload         jsonb,
  created_at      timestamptz not null default now()
);
create index if not exists idx_payments_order on public.payments (order_id);

-- -------------------------------------------------------------------------
-- 5. MÍDIA, CMS E ANALYTICS
-- -------------------------------------------------------------------------

create table if not exists public.media_files (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid references public.users (id) on delete set null,
  bucket        text not null default 'media',
  path          text not null,
  tipo          text, -- video | pdf | imagem
  created_at    timestamptz not null default now()
);

create table if not exists public.cms_content (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  tipo        text not null default 'pagina', -- pagina | bloco | post
  idioma      text not null default 'pt-BR',
  titulo      text,
  conteudo    jsonb,
  publicado   boolean not null default false,
  updated_at  timestamptz not null default now()
);

create table if not exists public.analytics_events (
  id          bigint generated always as identity primary key,
  user_id     uuid references public.users (id) on delete set null,
  evento      text not null, -- page_view | social_click | checkout_start | ...
  propriedades jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists idx_analytics_events_evento on public.analytics_events (evento);

-- -------------------------------------------------------------------------
-- 6. MÓDULO DE ACESSO REMOTO (manutenção de clientes)
-- -------------------------------------------------------------------------

create table if not exists public.remote_clients (
  id            uuid primary key default gen_random_uuid(),
  nome          text not null,
  segmento      text,
  logo_url      text,
  anos_parceria integer not null default 0,
  ativo         boolean not null default true,
  created_at    timestamptz not null default now()
);

create table if not exists public.client_services (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.remote_clients (id) on delete cascade,
  servico     text not null,
  status      text not null default 'ativo'
);

create table if not exists public.remote_configs (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.remote_clients (id) on delete cascade,
  chave       text not null,
  valor       jsonb not null,
  updated_at  timestamptz not null default now(),
  unique (client_id, chave)
);

create table if not exists public.remote_automations (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.remote_clients (id) on delete cascade,
  workflow    text not null, -- nome do workflow n8n
  ativo       boolean not null default true,
  ultima_execucao timestamptz
);

create table if not exists public.remote_logs (
  id          bigint generated always as identity primary key,
  client_id   uuid not null references public.remote_clients (id) on delete cascade,
  ator_user_id uuid references public.users (id) on delete set null,
  acao        text not null,
  detalhes    jsonb,
  timestamp   timestamptz not null default now()
);
create index if not exists idx_remote_logs_client on public.remote_logs (client_id);

-- -------------------------------------------------------------------------
-- 7. CLUSTERS OPCIONAIS — VAREJO E FOOD (desabilitados por padrão)
--    Descomente e ajuste quando estes clusters forem contratados/ativados.
-- -------------------------------------------------------------------------

-- create table if not exists public.varejo_clients (like public.remote_clients including all);
-- create table if not exists public.varejo_products (id uuid primary key default gen_random_uuid(), nome text, preco numeric(10,2));
-- create table if not exists public.varejo_services (id uuid primary key default gen_random_uuid(), nome text);
-- create table if not exists public.varejo_trails (id uuid primary key default gen_random_uuid(), titulo text);
-- create table if not exists public.varejo_quizzes (id uuid primary key default gen_random_uuid(), titulo text);
-- create table if not exists public.varejo_exams (id uuid primary key default gen_random_uuid(), titulo text);
-- create table if not exists public.varejo_logs (id bigint generated always as identity primary key, detalhes jsonb);

-- create table if not exists public.food_clients (like public.remote_clients including all);
-- create table if not exists public.food_products (id uuid primary key default gen_random_uuid(), nome text, preco numeric(10,2));
-- create table if not exists public.food_services (id uuid primary key default gen_random_uuid(), nome text);
-- create table if not exists public.food_menus (id uuid primary key default gen_random_uuid(), nome text, itens jsonb);
-- create table if not exists public.food_trails (id uuid primary key default gen_random_uuid(), titulo text);
-- create table if not exists public.food_quizzes (id uuid primary key default gen_random_uuid(), titulo text);
-- create table if not exists public.food_exams (id uuid primary key default gen_random_uuid(), titulo text);
-- create table if not exists public.food_logs (id bigint generated always as identity primary key, detalhes jsonb);

-- -------------------------------------------------------------------------
-- 8. SEED — papéis padrão
-- -------------------------------------------------------------------------

insert into public.roles (nome, descricao) values
  ('admin', 'Administrador do sistema — acesso total'),
  ('instrutor', 'Cria e gerencia cursos, trilhas e avaliações'),
  ('aluno', 'Acesso à área de membros e conteúdos matriculados'),
  ('cliente', 'Cliente com acesso ao painel de acompanhamento'),
  ('suporte', 'Equipe de suporte técnico'),
  ('tecnico', 'Executa diagnósticos e manutenção remota'),
  ('visitante', 'Acesso público, sem autenticação')
on conflict (nome) do nothing;

-- -------------------------------------------------------------------------
-- 9. ROW LEVEL SECURITY (RLS)
--    Habilita RLS em todas as tabelas sensíveis. As policies abaixo são um
--    ponto de partida seguro (usuário só vê o que é seu); refine conforme
--    os papéis reais de cada rota administrativa.
-- -------------------------------------------------------------------------

alter table public.users            enable row level security;
alter table public.enrollments      enable row level security;
alter table public.orders           enable row level security;
alter table public.order_items      enable row level security;
alter table public.payments         enable row level security;
alter table public.exam_results     enable row level security;
alter table public.logs_access      enable row level security;
alter table public.contact_messages enable row level security;
alter table public.remote_clients   enable row level security;
alter table public.remote_logs      enable row level security;

create policy "usuário vê o próprio perfil"
  on public.users for select
  using (auth.uid() = id);

create policy "usuário atualiza o próprio perfil"
  on public.users for update
  using (auth.uid() = id);

create policy "usuário vê as próprias matrículas"
  on public.enrollments for select
  using (auth.uid() = user_id);

create policy "usuário vê os próprios pedidos"
  on public.orders for select
  using (auth.uid() = user_id);

create policy "usuário vê os próprios resultados de prova"
  on public.exam_results for select
  using (auth.uid() = user_id);

-- Tabelas administrativas (remote_clients, payments, logs, contact_messages)
-- não recebem policy de leitura pública: acesso apenas via service role
-- (API routes server-side), conforme lib/supabaseClient.ts -> getSupabaseAdminClient().

-- -------------------------------------------------------------------------
-- 10. TRIGGER — updated_at automático
-- -------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger trg_courses_updated_at
  before update on public.courses
  for each row execute function public.set_updated_at();
