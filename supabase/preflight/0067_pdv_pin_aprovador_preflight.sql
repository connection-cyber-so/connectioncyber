-- Preflight 0067 (somente leitura). Rodar ANTES de aplicar a migration 0067, no staging.
-- Esperado: OK ou INFO em todas as linhas.

select 'OK/ATENCAO' as tipo, 'pgcrypto disponivel no schema extensions (crypt e gen_salt)' as check_name,
  case when exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'extensions' and p.proname in ('crypt'))
        and exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'extensions' and p.proname in ('gen_salt'))
       then 'OK' else 'ATENCAO' end as resultado
union all
select 'OK/ATENCAO', 'tabela erp_approver_pins ainda nao existe',
  case when to_regclass('public.erp_approver_pins') is null then 'OK' else 'ATENCAO' end
union all
select 'OK/ATENCAO', 'assinaturas antigas de erp_authorize_discount (7 args) e erp_authorize_cash_action (6 args) existem',
  case when to_regprocedure('public.erp_authorize_discount(uuid,uuid,uuid,uuid,numeric,numeric,text)') is not null
        and to_regprocedure('public.erp_authorize_cash_action(uuid,uuid,text,numeric,uuid,text)') is not null
       then 'OK' else 'ATENCAO' end
union all
select 'OK/ATENCAO', 'erp_security.has_permission e public.is_platform_staff existem',
  case when exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'erp_security' and p.proname = 'has_permission')
        and exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'is_platform_staff')
       then 'OK' else 'ATENCAO' end
union all
select 'INFO', concat('aprovadores com PIN cadastrado hoje: ', (select count(*) from public.erp_approver_pins)), null
union all
select 'INFO', 'nenhum PIN e cadastrado por esta migration; cada aprovador define o proprio PIN via erp_set_approver_pin', null;
