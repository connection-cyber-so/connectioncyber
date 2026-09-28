select
 case when exists(select 1 from supabase_migrations.schema_migrations where version='0032')then'OK_HISTORY_0032'else'FAIL_HISTORY'end history,
 case when to_regclass('public.erp_tenant_capability_exceptions')is not null then'OK_EXCEPTION_TABLE'else'FAIL_EXCEPTION_TABLE'end exception_table,
 case when to_regprocedure('public.erp_set_tenant_capability(uuid,text,text,text,integer,text,timestamptz,timestamptz)')is not null and to_regprocedure('public.erp_resolve_tenant_capabilities(uuid,timestamptz)')is not null and to_regprocedure('public.erp_revoke_capability_exception(uuid,uuid,timestamptz)')is not null then'OK_FUNCTIONS'else'FAIL_FUNCTIONS'end functions,
 case when exists(select 1 from information_schema.columns where table_schema='public'and table_name='erp_capability_catalog'and column_name='risk_level')and(select count(*)from information_schema.columns where table_schema='public'and table_name='erp_tenant_capabilities'and column_name in('source','contract_version','evidence_hash'))=3 then'OK_COLUMNS'else'FAIL_COLUMNS'end columns,
 case when exists(select 1 from public.erp_capability_catalog where key='device.agent'and risk_level='critical')then'OK_DEVICE_CAPABILITY'else'FAIL_DEVICE_CAPABILITY'end device_capability,
 case when exists(select 1 from public.erp_permissions where key='capabilities.read')then'OK_PERMISSION'else'FAIL_PERMISSION'end permission,
 case when(select relrowsecurity from pg_class where oid='public.erp_tenant_capability_exceptions'::regclass)then'OK_RLS'else'FAIL_RLS'end rls,
 case when not exists(select 1 from public.erp_tenant_capability_exceptions)then'OK_ZERO_EXCEPTIONS'else'FAIL_EXCEPTION_DATA'end exceptions_data,
 case when not exists(select 1 from public.tenants where slug like'm16-g3-synthetic-%')then'OK_ZERO_FIXTURES'else'FAIL_FIXTURES'end fixtures,
 case when not has_table_privilege('service_role','public.erp_tenant_capabilities','INSERT')and not has_table_privilege('service_role','public.erp_tenant_capabilities','UPDATE')and not has_table_privilege('service_role','public.erp_capability_catalog','INSERT')then'OK_LEAST_PRIVILEGE'else'FAIL_PRIVILEGES'end privileges;
