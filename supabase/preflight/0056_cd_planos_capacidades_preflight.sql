-- 0056 preflight (somente leitura). Rodar ANTES de aplicar a migration.
-- Esperado: 0 linhas em cada check de conflito; dependências 'ok' = 1 ou 'ativa' = true.

-- A) Chaves novas não podem existir no catálogo
select 'conflito_catalogo' as check, key from public.erp_capability_catalog
where key in ('cd.armazenagem', 'cd.expedicao', 'site.loja');

-- B) Tabela, função e trigger novos não podem existir
select 'conflito_tabela' as check, table_name from information_schema.tables
where table_schema = 'public' and table_name = 'erp_capability_dependencies';
select 'conflito_funcao' as check, proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'erp_enforce_capability_dependencies';
select 'conflito_trigger' as check, tgname from pg_trigger where tgname = 'trg_erp_tenant_capabilities_deps';

-- C) Dependências base ativas na Nuvem de Papel
select 'dep_inventory_stock_ativa' as check, count(*) as ok from public.erp_tenant_capabilities
where tenant_id = '00000000-0000-0000-0000-000000000001' and capability_key = 'inventory.stock' and status in ('trial', 'active');
select 'dep_sales_pos_ativa' as check, count(*) as ok from public.erp_tenant_capabilities
where tenant_id = '00000000-0000-0000-0000-000000000001' and capability_key = 'sales.pos' and status in ('trial', 'active');

-- D) Nuvem ainda sem as novas capacidades
select 'conflito_vinculo_nuvem' as check, capability_key from public.erp_tenant_capabilities
where tenant_id = '00000000-0000-0000-0000-000000000001' and capability_key in ('cd.armazenagem', 'cd.expedicao', 'site.loja');

-- E) Dependências das chaves 'inventory.stock' e 'sales.pos' existem no catálogo
select 'dep_catalogo_base' as check, count(*) as ok from public.erp_capability_catalog
where key in ('inventory.stock', 'sales.pos');
