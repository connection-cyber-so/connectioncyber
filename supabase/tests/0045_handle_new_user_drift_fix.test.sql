begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(11);

select ok(not exists (
  select 1 from pg_proc where oid = 'public.handle_new_user()'::regprocedure and prosrc like '%public.profiles%'
), 'hook nao grava em public.profiles');

select ok(exists (
  select 1 from pg_proc where oid = 'public.handle_new_user()'::regprocedure and prosrc like '%insert into public.users%'
), 'hook grava em public.users');

select ok(
  (select array_to_string(proconfig, ',') = 'search_path=""'
   from pg_proc where oid = 'public.handle_new_user()'::regprocedure),
  'hook usa search_path vazio'
);

select is(
  (select count(*) from pg_trigger
   where tgrelid = 'auth.users'::regclass and tgname = 'on_auth_user_created' and not tgisinternal),
  1::bigint, 'trigger de signup ativo'
);

select is(
  (select count(*) from auth.users u
   where u.email is not null
     and not exists (select 1 from public.users w where w.id = u.id)),
  0::bigint, 'nenhuma identidade orfa em relacao ao auth'
);

select is(
  has_function_privilege('anon', 'public.handle_new_user()', 'execute'),
  false, 'anon nao executa o hook'
);

insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('92000000-0000-4000-8000-000000000001','authenticated','authenticated','M23G0.Full@Example.Invalid','',
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Aluno 0045","tenant_id":"90000000-0000-4000-8000-000000000001"}',now(),now());
select ok(
  (select nome = 'Aluno 0045' and email = 'm23g0.full@example.invalid' and tenant_id is null
   from public.users where id = '92000000-0000-4000-8000-000000000001'),
  'signup cria identidade com nome, e-mail minusculo e sem tenant'
);

insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('92000000-0000-4000-8000-000000000002','authenticated','authenticated','Fallback@Example.Invalid','',
  '{"provider":"email","providers":["email"]}','{}',now(),now());
select ok(
  (select nome = 'fallback' and email = 'fallback@example.invalid'
   from public.users where id = '92000000-0000-4000-8000-000000000002'),
  'signup sem full_name usa o local-part do e-mail'
);

insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('92000000-0000-4000-8000-000000000003','authenticated','authenticated','Idem@Example.Invalid','',
  '{"provider":"email","providers":["email"]}','{"full_name":"Novo Nome"}',now(),now());
update public.users set nome = 'Nome Antigo' where id = '92000000-0000-4000-8000-000000000003';
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
select is(
  (select nome from public.users where id = '92000000-0000-4000-8000-000000000003'),
  'Nome Antigo', 'backfill nao sobrescreve identidade existente'
);

select throws_ok($$
  insert into auth.users (id,aud,role,email,encrypted_password,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values ('92000000-0000-4000-8000-000000000004','authenticated','authenticated',null,'',
          '{"provider":"email","providers":["email"]}','{}',now(),now())
$$,'23514','IDENTITY_EMAIL_REQUIRED','e-mail ausente e recusado no signup');

select ok(
  not has_function_privilege('authenticated', 'public.handle_new_user()', 'execute')
  and not has_function_privilege('public', 'public.handle_new_user()', 'execute'),
  'hook revogado de authenticated e public'
);

select * from finish();
rollback;
