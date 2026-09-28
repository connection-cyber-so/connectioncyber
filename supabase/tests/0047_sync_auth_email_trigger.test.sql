begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(7);

select ok(
  (select array_to_string(proconfig, ',') = 'search_path=""'
   from pg_proc where oid = 'public.sync_auth_email()'::regprocedure),
  'funcao de sincronismo usa search_path vazio'
);

select is(
  (select count(*) from pg_trigger
   where tgrelid = 'auth.users'::regclass
     and tgname = 'on_auth_user_email_changed' and not tgisinternal),
  1::bigint, 'trigger de troca de e-mail ativo'
);

select is(
  has_function_privilege('anon', 'public.sync_auth_email()', 'execute'),
  false, 'anon nao executa a sincronizacao'
);

insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('93000000-0000-4000-8000-000000000001','authenticated','authenticated','m23g0-sync-a@example.invalid','',
  '{"provider":"email","providers":["email"]}','{"full_name":"Aluno Sync"}',now(),now());
select is(
  (select email from public.users where id = '93000000-0000-4000-8000-000000000001'),
  'm23g0-sync-a@example.invalid', 'signup cria a identidade'
);

update auth.users set email = 'M23G0.Sync.B@Example.Invalid', updated_at = now()
 where id = '93000000-0000-4000-8000-000000000001';
select is(
  (select email from public.users where id = '93000000-0000-4000-8000-000000000001'),
  'm23g0.sync.b@example.invalid', 'troca de e-mail no Auth propaga em minusculas'
);

delete from public.users where id = '93000000-0000-4000-8000-000000000001';
update auth.users set email = 'm23g0-sync-c@example.invalid', updated_at = now()
 where id = '93000000-0000-4000-8000-000000000001';
select is(
  (select email from public.users where id = '93000000-0000-4000-8000-000000000001'),
  'm23g0-sync-c@example.invalid', 'identidade ausente e recriada com o e-mail novo'
);

update auth.users set email = null, updated_at = now()
 where id = '93000000-0000-4000-8000-000000000001';
select is(
  (select email from public.users where id = '93000000-0000-4000-8000-000000000001'),
  'm23g0-sync-c@example.invalid', 'e-mail nulo no Auth nao apaga a identidade'
);

select * from finish();
rollback;
