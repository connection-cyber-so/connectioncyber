-- Read-only; inspect output before apply. Alinha public.users.email ao Auth.
do $$
declare
  v_auth text;
  v_users text;
  v_dups int;
begin
  if not exists (select 1 from supabase_migrations.schema_migrations where version = '0045') then
    raise exception 'M23_HYGIENE_0046_PREFLIGHT: migration 0045 nao aplicada.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0046') then
    raise exception 'M23_HYGIENE_0046_PREFLIGHT: migration 0046 ja aplicada.';
  end if;
  if to_regclass('public.users') is null or to_regclass('auth.users') is null then
    raise exception 'M23_HYGIENE_0046_PREFLIGHT: tabelas de identidade ausentes.';
  end if;

  select lower(u.email) into v_auth
  from auth.users u where u.id = '61b57707-2292-49ff-8ca6-f43ccec087ed';

  if v_auth is not null then
    if v_auth = '' then
      raise exception 'M23_HYGIENE_0046_PREFLIGHT: auth.users sem e-mail vigente.';
    end if;
    select w.email into v_users
    from public.users w where w.id = '61b57707-2292-49ff-8ca6-f43ccec087ed';
    if v_users is not null and v_users <> v_auth then
      select count(*) into v_dups
      from public.users x where lower(x.email) = v_auth
        and x.id <> '61b57707-2292-49ff-8ca6-f43ccec087ed';
      if v_dups > 0 then
        raise exception 'M23_HYGIENE_0046_PREFLIGHT: e-mail vigente ja usado por outra identidade.';
      end if;
    end if;
  end if;
end $$;
select 'M23_HYGIENE_0046_PREFLIGHT_OK' as result,
       exists (select 1 from auth.users u
               where u.id = '61b57707-2292-49ff-8ca6-f43ccec087ed') as target_in_auth,
       exists (select 1 from public.users w
               where w.id = '61b57707-2292-49ff-8ca6-f43ccec087ed') as target_in_users,
       (select count(*) from public.users w join auth.users u on u.id = w.id
        where w.id = '61b57707-2292-49ff-8ca6-f43ccec087ed'
          and w.email is distinct from lower(u.email)) as divergences,
       now() as checked_at;
