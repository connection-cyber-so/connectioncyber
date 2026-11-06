-- 0057 preflight (somente leitura). Rodar ANTES de aplicar a migration.
-- Esperado: 0 linhas em cada check de conflito; dependências 'ok' com valor 1.
select 'conflito_tabela' as check, table_name from information_schema.tables
where table_schema = 'public' and table_name in ('cd_configuracoes', 'regras_saida', 'pedidos_cd', 'pedidos_cd_itens', 'transferencias', 'transferencia_itens', 'reservas');
select 'conflito_funcao' as check, proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'cd_valida_tipos_locais';
select 'dep_locais_0055' as check, count(*) as ok from information_schema.tables where table_schema = 'public' and table_name = 'locais';
select 'dep_enderecos_0055' as check, count(*) as ok from information_schema.tables where table_schema = 'public' and table_name = 'enderecos';
select 'dep_cd_set_updated_at' as check, count(*) as ok from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'cd_set_updated_at';
select 'dep_tenant_nuvem' as check, count(*) as ok from public.tenants where id = '00000000-0000-0000-0000-000000000001';
