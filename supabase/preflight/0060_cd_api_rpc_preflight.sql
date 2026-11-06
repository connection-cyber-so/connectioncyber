-- 0060 preflight (somente leitura). Esperado: conflito = vazio; dependências = 1.
select 'conflito_funcao' as check, proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('cd_api_exigir', 'cd_api_criar_pedido', 'cd_api_alocar_pedido', 'cd_api_receber_transferencia', 'cd_api_coletar_pedido', 'cd_api_despachar_pedido');
select 'dep_has_permission' as check, count(*) as ok from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'erp_security' and p.proname = 'has_permission';
select 'dep_internas_0058_0059' as check, count(*) as ok from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('cd_alocar_pedido', 'cd_receber_transferencia', 'cd_coletar_pedido', 'cd_despachar_pedido');
select 'dep_permissoes' as check, count(*) as ok from public.erp_permissions where key in ('stock.manage', 'sales.order') and active;
select 'dep_capacidades_cd' as check, count(*) as ok from public.erp_tenant_capabilities
where tenant_id = '00000000-0000-0000-0000-000000000001' and capability_key in ('cd.armazenagem', 'cd.expedicao') and status = 'active';
