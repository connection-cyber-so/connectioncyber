-- =========================================================================
-- ConnectionCyberSO — RLS em roles e user_roles
--
-- Achado (2026-08-15, revisão de arquitetura de acessos): roles e
-- user_roles nunca tiveram Row Level Security habilitado. Combinado com o
-- grant amplo de SELECT a "authenticated" (0008), isso significava que
-- qualquer usuário logado — inclusive um aluno comum — conseguia ler a
-- tabela user_roles inteira e ver quem mais é admin/suporte/instrutor etc.
-- Não havia grant de INSERT/UPDATE/DELETE para authenticated nessas duas
-- tabelas (0008 só devolveu escrita a tenants/users/enrollments/orders/
-- tenant_modules/tenant_themes), então nunca foi um risco de escrita — só
-- de leitura indevida.
--
-- Correção: cada usuário só enxerga o próprio papel; equipe ConnectionCyber
-- (is_platform_staff()) continua enxergando todos, como já faz em outras
-- tabelas do painel interno. roles (a lista de nomes de papéis em si, sem
-- vínculo com usuário) não é sensível — fica de leitura livre pra
-- authenticated, só formalizando o RLS ligado.
-- =========================================================================

alter table public.roles      enable row level security;
alter table public.user_roles enable row level security;

create policy roles_select_authenticated
  on public.roles
  for select
  to authenticated
  using (true);

create policy user_roles_select_own_or_staff
  on public.user_roles
  for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.is_platform_staff()
  );

comment on policy user_roles_select_own_or_staff on public.user_roles is
  'Cada usuário só lê o próprio papel; equipe ConnectionCyber (admin/suporte) lê todos — mesmo padrão de is_platform_staff() usado no resto do projeto.';
