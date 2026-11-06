-- 0055 preflight (somente leitura). Rodar ANTES de aplicar a migration.
-- Esperado: 0 linhas em cada check de conflito; tabelas inexistentes; dependências presentes.

-- A) Tabelas que a 0055 vai criar não podem existir
select 'conflito_tabela' as check, table_name
from information_schema.tables
where table_schema = 'public' and table_name in ('locais', 'enderecos', 'saldos');

-- B) Dependências existentes
select 'dep_tenants' as check, count(*) as ok from information_schema.tables
where table_schema = 'public' and table_name = 'tenants';
select 'dep_erp_security_is_tenant_member' as check, count(*) as ok
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'erp_security' and p.proname = 'is_tenant_member';
select 'dep_is_platform_staff' as check, count(*) as ok
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'is_platform_staff';

-- C) Função de trigger não pode existir com outro corpo
select 'conflito_funcao' as check, proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('enderecos_valida_tipo_local', 'cd_set_updated_at');

-- D) Tenant da Nuvem de Papel presente (base do primeiro teste de uso)
select 'tenant_nuvem' as check, count(*) as ok from public.tenants
where id = '00000000-0000-0000-0000-000000000001';
