-- Preflight 0062 (somente leitura). Rodar antes de aplicar a migration 0062.
-- Esperado: todas as linhas com resultado 'OK'. Qualquer 'ATENCAO' bloqueia a aplicação.

select 'fulfillments_com_linhas' as check_name,
       case when count(*) = 0 then 'OK' else 'ATENCAO' end as resultado,
       count(*)::text as detalhe
  from public.erp_food_fulfillments
union all
select 'colunas_novas_ja_existem',
       case when count(*) = 0 then 'OK' else 'ATENCAO' end,
       coalesce(string_agg(column_name, ', '), '-')
  from information_schema.columns
 where table_schema = 'public' and table_name = 'erp_food_fulfillments'
   and column_name in ('courier_kind', 'courier_party_id', 'courier_name', 'attempts', 'failure_reason',
                       'failed_at', 'distance_km', 'delivery_fee', 'fee_charge_mode')
union all
select 'tabela_zonas_ja_existe',
       case when count(*) = 0 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.tables
 where table_schema = 'public' and table_name = 'erp_delivery_fee_zones'
union all
select 'status_antigo_presente',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_constraint
 where conrelid = 'public.erp_food_fulfillments'::regclass and conname = 'erp_food_fulfillments_status_check'
union all
select 'erp_parties_unique_tenant_id',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_constraint
 where conrelid = 'public.erp_parties'::regclass and conname = 'erp_parties_tenant_id_unique'
union all
select 'erp_establishments_unique_tenant_id',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_constraint
 where conrelid = 'public.erp_establishments'::regclass and conname = 'erp_establishments_tenant_id_unique'
union all
select 'is_platform_staff_em_public',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname = 'is_platform_staff' and n.nspname = 'public'
union all
select 'has_permission_em_erp_security',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname = 'has_permission' and n.nspname = 'erp_security'
union all
select 'permissoes_food_existem',
       case when count(*) = 3 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from public.erp_permissions
 where key in ('food.read', 'food.manage', 'food.order');
