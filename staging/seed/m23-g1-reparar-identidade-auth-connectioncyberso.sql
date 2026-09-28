-- M23-G1 — Reparo da conta auth de connectioncyberso@gmail.com
-- Problema (dois defeitos na mesma linha auth.users, uid e2b88e26-94b9-4ead-8955-9d22f98d269b):
--   1) nao existia linha em auth.identities;
--   2) confirmation_token / recovery_token / email_change / email_change_token_new estavam NULL
--      (as demais contas tem '').
-- O GoTrue quebrava com 500 "Database error querying schema"/"Database error loading user" no
-- grant de senha (demais contas retornam 400 invalid_credentials normalmente) e o portal
-- mascarava tudo como "E-mail ou senha invalidos".
-- Corrigido em 28/09/2026: pos-reparo o grant de senha retorna 200 e /admin/users volta a 200.
-- Uso:      supabase db query --linked -f staging/seed/m23-g1-reparar-identidade-auth-connectioncyberso.sql
-- Idempotente: reexecutar nao altera nada (condicoes + valores já normalizados).

begin;

insert into auth.identities (id, provider, provider_id, user_id, identity_data, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(),
       'email',
       u.id::text,
       u.id,
       jsonb_build_object('sub', u.id::text,
                          'email', u.email,
                          'email_verified', (u.email_confirmed_at is not null),
                          'phone_verified', false),
       null,
       now(),
       now()
  from auth.users u
 where u.email = 'connectioncyberso@gmail.com'
   and not exists (select 1 from auth.identities i where i.user_id = u.id);

update auth.users u
   set confirmation_token = coalesce(nullif(u.confirmation_token, ''), ''),
       recovery_token = coalesce(nullif(u.recovery_token, ''), ''),
       email_change = coalesce(nullif(u.email_change, ''), ''),
       email_change_token_new = coalesce(nullif(u.email_change_token_new, ''), ''),
       email_change_token_current = coalesce(nullif(u.email_change_token_current, ''), ''),
       phone_change = coalesce(nullif(u.phone_change, ''),
                               ''),
       raw_user_meta_data = case when u.raw_user_meta_data = '{}'::jsonb
                                then jsonb_build_object('email_verified', u.email_confirmed_at is not null)
                                else u.raw_user_meta_data end
 where u.email = 'connectioncyberso@gmail.com'
   and (u.confirmation_token is null
     or u.recovery_token is null
     or u.email_change is null
     or u.email_change_token_new is null
     or u.email_change_token_current is null
     or u.phone_change is null);

select u.email,
       (u.email_confirmed_at is not null) as email_confirmado,
       (u.encrypted_password is not null) as tem_senha,
       (select count(*) from auth.identities i where i.user_id = u.id) as identidades,
       (select count(*) from public.erp_tenant_memberships m where m.user_id = u.id and m.status = 'active') as memberships_ativas
  from auth.users u
 where u.email = 'connectioncyberso@gmail.com';

commit;
