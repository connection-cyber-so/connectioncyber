-- 0059 preflight (somente leitura). Esperado: conflito = vazio; dependências = 1.
select 'conflito_funcao' as check, proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('cd_receber_transferencia', 'cd_coletar_pedido', 'cd_despachar_pedido');
select 'dep_alocar_pedido' as check, count(*) as ok from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'cd_alocar_pedido';
select 'dep_transferencias' as check, count(*) as ok from information_schema.tables where table_schema = 'public' and table_name = 'transferencias';
select 'dep_reservas' as check, count(*) as ok from information_schema.tables where table_schema = 'public' and table_name = 'reservas';
select 'dep_tenant_nuvem' as check, count(*) as ok from public.tenants where id = '00000000-0000-0000-0000-000000000001';
