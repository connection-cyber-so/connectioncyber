-- Rollback de contingencia da 0047: remove o trigger e a funcao de sincronismo.
-- Nao altera dados: identidades e e-mails ja sincronizados permanecem como estao.
begin;

drop trigger if exists on_auth_user_email_changed on auth.users;
drop function if exists public.sync_auth_email();

select 'M23_HYGIENE_0047_ROLLBACK_OK' as result, now() as applied_at;

commit;
