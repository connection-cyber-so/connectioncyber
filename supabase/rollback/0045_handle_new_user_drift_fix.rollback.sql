-- Rollback de contingencia da 0045: restaura a definicao pre-migracao (drift do
-- template, que gravava em public.profiles). NAO remove identidades recriadas pelo
-- backfill. Ao aplicar este arquivo o cadastro via Auth volta a nao criar
-- identidade em public.users — usar somente em emergencia.
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  insert into public.profiles (id, full_text, company_name, plan_type)
  values (new.id, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'company_name', 'free');
  return new;
end;
$function$;

comment on function public.handle_new_user() is
  'ROLLBACK 0045: definicao legada do template (grava em public.profiles). Nao cria identidade em public.users.';

revoke all on function public.handle_new_user() from public, anon, authenticated;

select 'M23_HYGIENE_0045_ROLLBACK_OK' as result, now() as applied_at;

commit;
