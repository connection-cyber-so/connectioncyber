do $$
declare v_missing text;
begin
 if current_setting('server_version_num')::integer<150000 then raise exception 'PostgreSQL 15+ required';end if;
 select string_agg(name,', 'order by name)into v_missing from unnest(array['tenants','erp_permissions','erp_memberships'])required(name)where to_regclass(format('public.%I',required.name))is null;
 if v_missing is not null then raise exception 'M16_G3_REQUIRED_OBJECTS_MISSING: %',v_missing;end if;
 if to_regprocedure('erp_security.has_permission(uuid,text)')is null then raise exception 'M16_G3_PERMISSION_FUNCTION_MISSING';end if;
 if to_regprocedure('public.is_platform_staff()')is null then raise exception 'M16_G3_STAFF_FUNCTION_MISSING';end if;
 if to_regclass('supabase_migrations.schema_migrations')is null then raise exception 'MIGRATION_HISTORY_MISSING';end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='0031')then raise exception 'M16_G3_REQUIRED_MIGRATION_0031_MISSING';end if;
 if to_regclass('public.erp_capability_catalog')is not null or to_regclass('public.erp_tenant_capability_entitlements')is not null or to_regclass('public.erp_tenant_capability_exceptions')is not null then raise exception 'M16_G3_OBJECT_COLLISION';end if;
 if exists(select 1 from public.tenants where slug like'm16-g3-synthetic-%')then raise exception 'M16_G3_STALE_FIXTURES_FOUND';end if;
end$$;
select now()checked_at,'M16_G3_PREFLIGHT_OK'result;
