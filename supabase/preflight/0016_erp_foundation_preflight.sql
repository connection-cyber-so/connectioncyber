-- ConnectionCyber — M02 — preflight somente leitura
-- Execute antes de aplicar 0016_erp_foundation.sql no Supabase staging.
-- Este arquivo não cria, altera nem remove objetos.

do $$
declare
  conflicting_objects text[];
  migration_already_applied boolean := false;
begin
  if current_setting('server_version_num')::integer < 150000 then
    raise exception 'M02_PREFLIGHT: PostgreSQL 15+ é obrigatório (encontrado %).', version();
  end if;

  if to_regclass('public.tenants') is null
     or to_regclass('public.users') is null then
    raise exception 'M02_PREFLIGHT: tabelas public.tenants/public.users ausentes.';
  end if;

  if to_regprocedure('public.set_updated_at()') is null
     or to_regprocedure('public.is_platform_staff()') is null then
    raise exception 'M02_PREFLIGHT: helpers set_updated_at/is_platform_staff ausentes.';
  end if;

  select array_agg(format('%I.%I', n.nspname, c.relname) order by c.relname)
    into conflicting_objects
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p', 'v', 'm', 'f')
    and c.relname = any (array[
      'erp_tenant_memberships', 'erp_roles', 'erp_permissions',
      'erp_role_permissions', 'erp_membership_roles', 'erp_establishments',
      'erp_capability_catalog', 'erp_tenant_capabilities',
      'erp_segment_profiles', 'erp_segment_profile_capabilities',
      'erp_tenant_segment_profiles', 'erp_tenant_settings',
      'erp_number_sequences', 'erp_audit_events'
    ]);

  if conflicting_objects is not null then
    raise exception 'M02_PREFLIGHT: objetos ERP já existem: %', conflicting_objects;
  end if;

  if exists (select 1 from pg_namespace where nspname = 'erp_security') then
    raise exception 'M02_PREFLIGHT: schema erp_security já existe; investigar antes de avançar.';
  end if;

  if to_regclass('supabase_migrations.schema_migrations') is not null then
    execute
      'select exists (select 1 from supabase_migrations.schema_migrations where version = $1)'
      into migration_already_applied
      using '0016';
  end if;

  if migration_already_applied then
    raise exception 'M02_PREFLIGHT: migration 0016 já consta no histórico remoto.';
  end if;
end
$$;

select
  'M02_PREFLIGHT_OK' as result,
  current_database() as database_name,
  current_user as executed_by,
  version() as postgres_version,
  now() as checked_at;
