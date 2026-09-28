-- M23 0.1.0 (higiene de identidade): additive; apply only after preflight.
-- Drift observado no Supabase staging: public.handle_new_user() gravava em
-- public.profiles (template) e nunca em public.users, entao o cadastro via Auth
-- nao criava a identidade no ERP. Reafirma a definicao autoritativa da migration
-- 0018 e repara identidades orfas. Idempotente e nao destrutivo.
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name text;
begin
  if new.email is null or btrim(new.email) = '' then
    raise exception 'IDENTITY_EMAIL_REQUIRED' using errcode = '23514';
  end if;

  display_name := coalesce(
    nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    split_part(lower(new.email), '@', 1)
  );

  insert into public.users (id, nome, email, tenant_id)
  values (new.id, display_name, lower(new.email), null)
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Cria somente o profile da identidade em public.users. Ignora tenant_id em metadata e nao aplica fallback; memberships sao provisionadas server-only.';

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- O hook de signup precisa existir (ambientes template podem nao tê-lo).
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'auth.users'::regclass
      and tgname = 'on_auth_user_created'
      and not tgisinternal
  ) then
    create trigger on_auth_user_created
      after insert on auth.users
      for each row
      execute function public.handle_new_user();
  end if;
end $$;

-- Reparo de identidades orfas: auth.users sem linha correspondente em public.users.
insert into public.users (id, nome, email, tenant_id)
select u.id,
       coalesce(nullif(btrim(u.raw_user_meta_data->>'full_name'), ''), split_part(lower(u.email), '@', 1)),
       lower(u.email),
       null
from auth.users u
where u.email is not null
  and btrim(u.email) <> ''
  and not exists (select 1 from public.users w where w.id = u.id)
on conflict do nothing;

commit;
