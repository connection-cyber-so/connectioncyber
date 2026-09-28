-- Read-only; inspect output before apply. Sincronismo de e-mail Auth -> public.users.
do $$
begin
  if not exists (select 1 from supabase_migrations.schema_migrations where version = '0046') then
    raise exception 'M23_HYGIENE_0047_PREFLIGHT: migration 0046 nao aplicada.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0047') then
    raise exception 'M23_HYGIENE_0047_PREFLIGHT: migration 0047 ja aplicada.';
  end if;
  if to_regclass('public.users') is null or to_regclass('auth.users') is null then
    raise exception 'M23_HYGIENE_0047_PREFLIGHT: tabelas de identidade ausentes.';
  end if;
end $$;
select 'M23_HYGIENE_0047_PREFLIGHT_OK' as result,
       (to_regprocedure('public.sync_auth_email()') is not null) as function_present,
       exists (select 1 from pg_trigger
               where tgrelid = 'auth.users'::regclass
                 and tgname = 'on_auth_user_email_changed' and not tgisinternal) as trigger_present,
       (select count(*) from public.users w join auth.users u on u.id = w.id
        where w.email is distinct from lower(u.email)) as divergences,
       now() as checked_at;
