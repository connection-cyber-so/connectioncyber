-- =========================================================================
-- ConnectionCyberSO — Corrige o escopo do grant a "authenticated"
-- (autorrevisão imediatamente após 0007, antes de qualquer uso real)
--
-- 0007 deu INSERT/UPDATE/DELETE para "authenticated" em TODAS as tabelas.
-- Isso é seguro nas tabelas que já têm RLS + policy própria (tenants,
-- users, enrollments, orders, tenant_modules, tenant_themes) — RLS
-- restringe por linha. Mas é um risco real nas tabelas SEM RLS habilitado
-- (courses, products, quizzes, cms_content, etc.): sem policy nenhuma para
-- filtrar, o GRANT sozinho permitiria qualquer usuário autenticado (ex: um
-- aluno) escrever/apagar no catálogo de cursos, produtos, etc.
--
-- Correção: authenticated passa a ter só SELECT por padrão em todo o
-- schema; INSERT/UPDATE/DELETE ficam explícitos apenas nas tabelas que já
-- têm RLS + policy real protegendo a linha. Toda escrita administrativa
-- (cursos, produtos, CMS...) continua passando por service_role em API
-- routes — é assim que o código já funciona hoje (ver src/pages/api/*.ts,
-- getSupabaseAdminClient()), então isso não regride nada em uso.
-- =========================================================================

revoke insert, update, delete on all tables in schema public from authenticated;
alter default privileges in schema public revoke insert, update, delete on tables from authenticated;
alter default privileges in schema public grant select on tables to authenticated;

-- Tabelas com RLS + policy própria já validada (0001-0006): liberar DML aqui é seguro.
grant insert, update, delete on public.tenants          to authenticated;
grant insert, update, delete on public.users             to authenticated;
grant insert, update, delete on public.enrollments        to authenticated;
grant insert, update, delete on public.orders              to authenticated;
grant insert, update, delete on public.tenant_modules       to authenticated;
grant insert, update, delete on public.tenant_themes         to authenticated;
