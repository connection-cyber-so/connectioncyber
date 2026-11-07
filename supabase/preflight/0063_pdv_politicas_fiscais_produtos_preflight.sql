-- Preflight 0063 (somente leitura). Rodar antes de aplicar a migration 0063.
-- Esperado: todas as linhas 'OK' ou 'INFO'. Qualquer 'ATENCAO' bloqueia a aplicação.

select 'colunas_flags_nao_existem' as check_name,
       case when count(*) = 0 then 'OK' else 'ATENCAO' end as resultado,
       coalesce(string_agg(column_name, ', '), '-') as detalhe
  from information_schema.columns
 where table_schema = 'public' and table_name = 'erp_catalog_items'
   and column_name in ('age_restricted', 'fumigeno')
union all
select 'allows_fraction_existe',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.columns
 where table_schema = 'public' and table_name = 'erp_catalog_items' and column_name = 'allows_fraction'
union all
select 'tabela_alcada_nao_existe',
       case when count(*) = 0 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.tables
 where table_schema = 'public' and table_name = 'erp_discount_authorizations'
union all
select 'erp_sales_unique_tenant_id',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_constraint
 where conrelid = 'public.erp_sales'::regclass and conname = 'erp_sales_tenant_id_id_key'
union all
select 'erp_establishments_unique_tenant_id',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_constraint
 where conrelid = 'public.erp_establishments'::regclass and conname = 'erp_establishments_tenant_id_unique'
union all
select 'permissoes_pdv_existem',
       case when count(*) = 5 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from public.erp_permissions
 where key in ('sales.discount', 'sales.read', 'cash.adjust', 'cash.close', 'fiscal.issue')
union all
select 'has_permission_existe',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname = 'has_permission' and n.nspname = 'erp_security'
union all
select 'is_platform_staff_existe',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname = 'is_platform_staff' and n.nspname = 'public'
union all
select 'chaves_seed_ja_existem',
       case when count(*) = 0 then 'OK' else 'INFO' end,
       count(*)::text
  from public.erp_tenant_settings
 where key in ('pdv.discount.auto_limit_percent', 'pdv.fiscal.emit_nfce_by_channel', 'pdv.kitchen.print_on_accept')
   and establishment_id is null
union all
select 'tenants_no_staging',
       'INFO',
       count(*)::text
  from public.tenants;
