-- ConnectionCyber — M03 — preflight somente leitura da migration 0017
-- Não cria, altera nem remove objetos.

do $$
declare
  migration_already_applied boolean := false;
  conflicting_objects text[];
  legacy_domain_duplicates text[];
begin
  if current_setting('server_version_num')::integer < 150000 then
    raise exception 'M03_PREFLIGHT: PostgreSQL 15+ é obrigatório (encontrado %).', version();
  end if;

  if to_regclass('public.tenants') is null
     or to_regclass('public.users') is null
     or to_regclass('public.erp_tenant_memberships') is null then
    raise exception 'M03_PREFLIGHT: fundação M02 incompleta.';
  end if;

  if to_regprocedure('public.set_updated_at()') is null
     or to_regprocedure('erp_security.is_tenant_member(uuid)') is null then
    raise exception 'M03_PREFLIGHT: helpers obrigatórios ausentes.';
  end if;

  select array_agg(format('%I.%I', n.nspname, c.relname) order by c.relname)
    into conflicting_objects
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'erp_tenant_domains'
    and c.relkind in ('r', 'p', 'v', 'm', 'f');

  if conflicting_objects is not null
     or to_regprocedure('public.portal_resolve_host(text)') is not null
     or to_regprocedure('erp_security.normalize_hostname(text)') is not null then
    raise exception 'M03_PREFLIGHT: objetos 0017 já existem; investigar antes de avançar.';
  end if;

  if exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and policyname in (
        'erp_tenant_domains_select_own_membership',
        'tenants_select_erp_membership'
      )
  ) then
    raise exception 'M03_PREFLIGHT: policy 0017 já existe; investigar antes de avançar.';
  end if;

  select array_agg(normalized_domain order by normalized_domain)
    into legacy_domain_duplicates
  from (
    select lower(trim(trailing '.' from btrim(dominio))) as normalized_domain
    from public.tenants
    where nullif(btrim(dominio), '') is not null
    group by lower(trim(trailing '.' from btrim(dominio)))
    having count(*) > 1
  ) duplicates;

  if legacy_domain_duplicates is not null then
    raise exception
      'M03_PREFLIGHT: tenants.dominio possui duplicidades normalizadas: %',
      legacy_domain_duplicates;
  end if;

  if to_regclass('supabase_migrations.schema_migrations') is not null then
    execute
      'select exists (select 1 from supabase_migrations.schema_migrations where version = $1)'
      into migration_already_applied
      using '0017';
  end if;

  if migration_already_applied then
    raise exception 'M03_PREFLIGHT: migration 0017 já consta no histórico remoto.';
  end if;
end
$$;

select
  'M03_PREFLIGHT_OK' as result,
  current_database() as database_name,
  current_user as executed_by,
  version() as postgres_version,
  (select count(*) from public.tenants where nullif(btrim(dominio), '') is not null)
    as legacy_domains_observed,
  now() as checked_at;
