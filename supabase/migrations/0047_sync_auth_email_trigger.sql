-- M23 0.1.0 (higiene de identidade): additive; apply only after preflight.
-- Trocas de e-mail feitas no Auth nao propagavam para public.users (so existia o hook
-- de INSERT, da migration 0003/0018). Cria a funcao de sincronizacao e o trigger de
-- UPDATE. Se a identidade estiver ausente (drift da 0045), ela e recriada.
begin;

create or replace function public.sync_auth_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name text;
begin
  if new.email is null or btrim(new.email) = '' then
    return new;
  end if;

  display_name := coalesce(
    nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    split_part(lower(new.email), '@', 1)
  );

  insert into public.users as w (id, nome, email, tenant_id)
  values (new.id, display_name, lower(new.email), null)
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now()
    where w.email is distinct from excluded.email;

  return new;
end;
$$;

comment on function public.sync_auth_email() is
  'Propaga auth.users.email para public.users (update da identidade ou recriacao se ausente). Se o e-mail novo ja pertencer a outra identidade, a troca no Auth falha por unicidade.';

revoke all on function public.sync_auth_email() from public, anon, authenticated;

drop trigger if exists on_auth_user_email_changed on auth.users;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.sync_auth_email();

commit;
