-- Read-only; inspect output before apply. Drift da 0045: hook gravando em public.profiles.
do $$
begin
  if to_regclass('public.users') is null
     or (select count(distinct column_name) from information_schema.columns
         where table_schema = 'public' and table_name = 'users'
           and column_name in ('id', 'nome', 'email', 'tenant_id')) <> 4 then
    raise exception 'M23_HYGIENE_0045_PREFLIGHT: public.users incompleta (id, nome, email, tenant_id).';
  end if;
  if to_regclass('auth.users') is null then
    raise exception 'M23_HYGIENE_0045_PREFLIGHT: auth.users ausente.';
  end if;
  if not exists (select 1 from supabase_migrations.schema_migrations where version = '0018') then
    raise exception 'M23_HYGIENE_0045_PREFLIGHT: migration 0018 (identidade) nao aplicada.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0045') then
    raise exception 'M23_HYGIENE_0045_PREFLIGHT: migration 0045 ja aplicada.';
  end if;
end $$;
select 'M23_HYGIENE_0045_PREFLIGHT_OK' as result,
       (to_regprocedure('public.handle_new_user()') is null
        or exists (select 1 from pg_proc
                   where oid = 'public.handle_new_user()'::regprocedure
                     and prosrc like '%public.profiles%')) as drift_present,
       (select count(*) from auth.users u
        where not exists (select 1 from public.users w where w.id = u.id)) as orphans_pending,
       (select count(*) from pg_trigger
        where tgrelid = 'auth.users'::regclass
          and tgname = 'on_auth_user_created' and not tgisinternal) as signup_triggers,
       now() as checked_at;
