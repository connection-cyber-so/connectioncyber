select * from(
 select 'history'::text kind,coalesce((select string_agg(version,','order by version)from supabase_migrations.schema_migrations where version='0032'),'absent')::text value,''::text detail,''::text extra
 union all
 select 'relation',n.nspname||'.'||c.relname,c.relkind::text,c.relrowsecurity::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relname in('erp_capability_catalog','erp_tenant_capability_entitlements','erp_tenant_capability_exceptions')
 union all
 select 'function',n.nspname||'.'||p.proname,pg_get_function_identity_arguments(p.oid),p.prosecdef::text from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname in('erp_resolve_tenant_capabilities','erp_revoke_capability_exception')
 union all
 select 'policy',schemaname||'.'||tablename,policyname,roles::text from pg_policies where schemaname='public'and tablename in('erp_capability_catalog','erp_tenant_capability_entitlements','erp_tenant_capability_exceptions')
)audit order by kind,value,detail;
