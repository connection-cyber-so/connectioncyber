-- Preflight 0065 (somente leitura). Rodar antes de aplicar a migration 0065.
-- Esperado: 'OK' ou 'INFO'. Qualquer 'ATENCAO' bloqueia a aplicação.

select 'funcao_rpc_nao_existe' as check_name,
       case when count(*) = 0 then 'OK' else 'ATENCAO' end as resultado,
       count(*)::text as detalhe
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'erp_authorize_discount'
union all
select 'policy_insert_0063_presente',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_policies
 where schemaname = 'public' and tablename = 'erp_discount_authorizations'
   and policyname = 'erp_discount_authorizations_insert'
union all
select 'tabela_alcada_existe',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.tables
 where table_schema = 'public' and table_name = 'erp_discount_authorizations'
union all
select 'colunas_membership_vigencia',
       case when count(*) = 3 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.columns
 where table_schema = 'public' and table_name = 'erp_tenant_memberships'
   and column_name in ('status', 'starts_at', 'ends_at')
union all
select 'users_ativo_e_tenants_ativo',
       case when count(*) = 2 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from information_schema.columns
 where (table_schema = 'public' and table_name = 'users' and column_name = 'ativo')
    or (table_schema = 'public' and table_name = 'tenants' and column_name = 'ativo')
union all
select 'has_permission_existe',
       case when count(*) = 1 then 'OK' else 'ATENCAO' end,
       count(*)::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where p.proname = 'has_permission' and n.nspname = 'erp_security'
union all
select 'candidatos_aprovador_no_staging',
       'INFO',
       count(distinct m.tenant_id)::text
  from public.erp_tenant_memberships m
  join public.erp_membership_roles mr on mr.tenant_id = m.tenant_id and mr.membership_id = m.id
  join public.erp_role_permissions rp on rp.tenant_id = mr.tenant_id and rp.role_id = mr.role_id
  join public.erp_permissions p on p.id = rp.permission_id
 where p.key = 'sales.discount' and m.status = 'active'
union all
select 'alcada_linhas_antes',
       'INFO',
       count(*)::text
  from public.erp_discount_authorizations;
