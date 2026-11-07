-- Preflight 0066 (somente leitura). Rodar ANTES de aplicar a migration 0066, no staging.
-- Esperado: todas as linhas OK ou INFO. Qualquer ATENCAO bloqueia a aplicação.

select 'OK/ATENCAO' as tipo, 'unique (tenant_id,id) em erp_cash_sessions (pre-requisito das FKs)' as check_name,
  case when exists (
    select 1 from pg_index i
      join pg_class c on c.oid = i.indrelid
     where c.oid = 'public.erp_cash_sessions'::regclass and i.indisunique
       and (select array_agg(a.attname order by a.attname) from pg_attribute a where a.attrelid = c.oid and a.attnum = any(i.indkey)) = array['id','tenant_id']::name[]
  ) then 'OK' else 'ATENCAO' end as resultado
union all
select 'OK/ATENCAO', 'tipos de movimento incluem withdrawal e check de direction',
  case when exists (select 1 from pg_constraint where conrelid = 'public.erp_cash_movements'::regclass and pg_get_constraintdef(oid) like '%withdrawal%')
        and exists (select 1 from pg_constraint where conrelid = 'public.erp_cash_movements'::regclass and pg_get_constraintdef(oid) like '%''out''%')
       then 'OK' else 'ATENCAO' end
union all
select 'OK/ATENCAO', 'erp_tenant_settings aceita key e sensitivity internal',
  case when exists (select 1 from pg_constraint where conrelid = 'public.erp_tenant_settings'::regclass and pg_get_constraintdef(oid) like '%internal%')
       then 'OK' else 'ATENCAO' end
union all
select 'OK/ATENCAO', 'colunas novas ainda nao existem (authorization_id, closing_authorization_id, erp_cash_authorizations)',
  case when not exists (select 1 from information_schema.columns where table_schema='public' and table_name='erp_cash_movements' and column_name='authorization_id')
        and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='erp_cash_sessions' and column_name='closing_authorization_id')
        and to_regclass('public.erp_cash_authorizations') is null
       then 'OK' else 'ATENCAO' end
union all
select 'OK/ATENCAO', 'erp_security.has_permission e public.is_platform_staff existem',
  case when exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'erp_security' and p.proname = 'has_permission')
        and exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'is_platform_staff')
       then 'OK' else 'ATENCAO' end
union all
select 'INFO', 'sessoes de caixa e movimentos no staging (linhas afetadas pelo gate: 0 esperado)', null
union all
select 'INFO', concat('sessoes=', (select count(*) from public.erp_cash_sessions), ' movimentos=', (select count(*) from public.erp_cash_movements)), null
union all
select 'INFO', 'candidatos a aprovador com cash.adjust e cash.close (tenant 7f2f05c7 usado no teste)',
  case when exists (
    select 1 from public.erp_tenant_memberships m
     where m.tenant_id = '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3' and m.user_id = '72d1f5ee-0e6b-4551-bba2-dff88a7766e1' and m.status = 'active'
  ) then 'OK' else 'ATENCAO' end;
