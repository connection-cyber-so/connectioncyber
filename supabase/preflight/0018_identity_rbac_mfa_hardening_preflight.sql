-- ConnectionCyber — M04-G1 — preflight somente leitura da migration 0018
-- Não cria, altera nem remove objetos.

do $$
declare
  migration_already_applied boolean := false;
  profile_gaps bigint;
  conflicting_columns text[];
begin
  if current_setting('server_version_num')::integer < 150000 then
    raise exception 'M04_PREFLIGHT: PostgreSQL 15+ é obrigatório (encontrado %).', version();
  end if;

  if to_regclass('public.users') is null
     or to_regclass('public.erp_tenant_memberships') is null
     or to_regclass('public.erp_roles') is null
     or to_regclass('public.erp_permissions') is null
     or to_regclass('public.erp_tenant_domains') is null then
    raise exception 'M04_PREFLIGHT: fundações M02/M03 incompletas.';
  end if;

  if to_regprocedure('public.handle_new_user()') is null
     or to_regprocedure('public.custom_access_token_hook(jsonb)') is null
     or to_regprocedure('erp_security.has_permission(uuid,text)') is null then
    raise exception 'M04_PREFLIGHT: helpers obrigatórios ausentes.';
  end if;

  if to_regclass('public.erp_identity_provisioning_runs') is not null
     or to_regclass('public.erp_identity_provisioning_steps') is not null
     or to_regprocedure('erp_security.current_aal()') is not null
     or to_regprocedure('erp_security.has_permission_at_aal(uuid,text,text)') is not null then
    raise exception 'M04_PREFLIGHT: objetos 0018 já existem; investigar antes de avançar.';
  end if;

  select array_agg(format('%s.%s', table_name, column_name) order by table_name, column_name)
    into conflicting_columns
  from information_schema.columns
  where table_schema = 'public'
    and (
      (table_name = 'erp_roles' and column_name in ('requires_mfa', 'sensitivity'))
      or (table_name = 'erp_tenant_memberships' and column_name in (
        'invited_at', 'activated_at', 'suspended_at', 'revoked_at', 'invitation_expires_at'
      ))
    );

  if conflicting_columns is not null then
    raise exception 'M04_PREFLIGHT: colunas 0018 já existem: %', conflicting_columns;
  end if;

  select count(*) into profile_gaps
  from auth.users identity
  left join public.users profile on profile.id = identity.id
  where profile.id is null;

  if profile_gaps <> 0 then
    raise exception 'M04_PREFLIGHT: % identidades Auth não possuem profile.', profile_gaps;
  end if;

  if exists (select 1 from public.users where tenant_id is null) then
    raise exception 'M04_PREFLIGHT: já existem profiles com tenant legado nulo; investigar origem.';
  end if;

  if to_regclass('supabase_migrations.schema_migrations') is not null then
    execute
      'select exists (select 1 from supabase_migrations.schema_migrations where version = $1)'
      into migration_already_applied
      using '0018';
  end if;

  if migration_already_applied then
    raise exception 'M04_PREFLIGHT: migration 0018 já consta no histórico.';
  end if;
end
$$;

select
  'M04_PREFLIGHT_OK' as result,
  current_database() as database_name,
  current_user as executed_by,
  (select count(*) from auth.users) as auth_identities_observed,
  (select count(*) from public.users) as profiles_observed,
  (select count(*) from public.erp_tenant_memberships) as memberships_observed,
  (select count(*) from public.erp_roles) as erp_roles_observed,
  now() as checked_at;
