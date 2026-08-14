-- =========================================================================
-- ConnectionCyberSO — Grants faltantes (achado durante verificação do
-- povoamento de tenants reais, 2026-08-13)
--
-- Diagnóstico: nenhuma migration anterior concedeu GRANT de tabela para
-- nenhum papel — só RLS foi habilitado. RLS filtra LINHAS; GRANT é o
-- pré-requisito de acesso a nível de Postgres que vem antes disso. Sem
-- GRANT, nem o service_role (uso interno/confiável, deveria enxergar tudo)
-- conseguia ler as tabelas — confirmado por um erro 42501 ao validar o
-- povoamento de tenants.
--
-- Diferente do antipadrão encontrado na auditoria de bpo-system-web-os
-- (GRANT ALL para "anon" — visitante anônimo com escrita liberada em toda
-- tabela), aqui o escopo é deliberadamente mais estreito:
--   - service_role: acesso total (é o papel de uso server-side/administrativo,
--     nunca exposto ao navegador — ver lib/supabaseClient.ts,
--     getSupabaseAdminClient()).
--   - authenticated: acesso a nível de GRANT, mas toda tabela sensível já
--     tem RLS habilitado com policy própria (ver 0001-0006) — RLS continua
--     sendo a camada real de isolamento por linha/tenant.
--   - anon: NENHUM grant novo. Visitante não-autenticado continua sem
--     acesso a nenhuma tabela — o site funciona em modo demonstração
--     (dados estáticos no código) justamente para não depender disso.
-- =========================================================================

grant usage on schema public to authenticated, service_role;

grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant all on all routines in schema public to service_role;

grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

alter default privileges in schema public grant all on tables to service_role;
alter default privileges in schema public grant all on sequences to service_role;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
