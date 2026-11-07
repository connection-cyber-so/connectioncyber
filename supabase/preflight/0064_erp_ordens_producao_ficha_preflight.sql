-- Preflight 0064 (somente leitura). Rodar antes de aplicar a migration 0064.
-- Esperado: todas as linhas 'OK' (ou 'INFO'). Qualquer 'ATENCAO' bloqueia a aplicação.

select 'tabela_ordens_nao_existe' as check_name,
       case when count(*) = 0 then 'OK' else 'ATENCAO' end as resultado,
       count(*)::text as detalhe
  from information_schema.tables
 where table_schema = 'public' and table_name = 'erp_production_orders'
union all
select 'view_requisitos_nao_existe',
       case when count(*) = 0 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.views
 where table_schema = 'public' and table_name = 'erp_production_order_requirements'
union all
select 'tabelas_base_existem',
       case when count(*) = 5 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.tables
 where table_schema = 'public'
   and table_name in ('erp_item_compositions', 'erp_item_composition_lines', 'erp_catalog_items', 'erp_units', 'erp_establishments')
union all
select 'unique_tenant_id_nas_pais',
       case when count(*) = 5 then 'OK' else 'ATENCAO' end,
       string_agg(conrelid::regclass::text, ', ')
  from pg_constraint
 where contype = 'u'
   and pg_get_constraintdef(oid) = 'UNIQUE (tenant_id, id)'
   and conrelid in (
     'public.erp_item_compositions'::regclass,
     'public.erp_catalog_items'::regclass,
     'public.erp_units'::regclass,
     'public.erp_establishments'::regclass,
     'public.erp_item_composition_lines'::regclass
   )
union all
select 'permissoes_stock_existem',
       case when count(*) = 3 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from public.erp_permissions
 where key in ('stock.read', 'stock.manage', 'stock.count')
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
select 'fichas_no_staging',
       'INFO',
       count(*)::text
  from public.erp_item_compositions;
