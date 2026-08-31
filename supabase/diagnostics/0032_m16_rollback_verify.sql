select
 case when exists(select 1 from supabase_migrations.schema_migrations where version='0032')then'FAIL_HISTORY'else'OK_HISTORY_ABSENT'end history,
 case when to_regclass('public.erp_tenant_capability_exceptions')is null then'OK_EXCEPTION_TABLE_ABSENT'else'FAIL_EXCEPTION_TABLE'end exception_table,
 case when to_regprocedure('public.erp_set_tenant_capability(uuid,text,text,text,integer,text,timestamptz,timestamptz)')is null and to_regprocedure('public.erp_resolve_tenant_capabilities(uuid,timestamptz)')is null and to_regprocedure('public.erp_revoke_capability_exception(uuid,uuid,timestamptz)')is null then'OK_FUNCTIONS_ABSENT'else'FAIL_FUNCTIONS'end functions,
 case when not exists(select 1 from information_schema.columns where table_schema='public'and table_name='erp_capability_catalog'and column_name='risk_level')and not exists(select 1 from information_schema.columns where table_schema='public'and table_name='erp_tenant_capabilities'and column_name in('source','contract_version','evidence_hash'))then'OK_COLUMNS_ABSENT'else'FAIL_COLUMNS'end columns,
 case when not exists(select 1 from public.erp_capability_catalog where key='device.agent')then'OK_DEVICE_CAPABILITY_ABSENT'else'FAIL_DEVICE_CAPABILITY'end device_capability,
 case when not exists(select 1 from public.erp_permissions where key='capabilities.read')then'OK_PERMISSION_ABSENT'else'FAIL_PERMISSION'end permission,
 case when not exists(select 1 from public.tenants where slug like'm16-g3-synthetic-%')then'OK_FIXTURES_ABSENT'else'FAIL_FIXTURES'end fixtures;
