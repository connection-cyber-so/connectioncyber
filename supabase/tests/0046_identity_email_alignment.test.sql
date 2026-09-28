begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(4);

select ok(
  not exists (
    select 1 from public.users w join auth.users u on u.id = w.id
    where w.id = '61b57707-2292-49ff-8ca6-f43ccec087ed'
      and w.email is distinct from lower(u.email)
  ), 'identidade alinhada ao e-mail vigente do Auth'
);

select ok(
  (select count(*) from public.users x
   where lower(x.email) = (select lower(u.email) from auth.users u
                           where u.id = '61b57707-2292-49ff-8ca6-f43ccec087ed')) <= 1,
  'e-mail sem duplicidade em public.users'
);

select ok(
  not exists (select 1 from auth.users u
              where u.id = '61b57707-2292-49ff-8ca6-f43ccec087ed'
                and (u.email is null or btrim(u.email) = '')),
  'auth mantem e-mail vigente nao vazio'
);

select ok(
  not exists (select 1 from public.users w
              where w.id = '61b57707-2292-49ff-8ca6-f43ccec087ed'
                and (w.nome is null or btrim(w.nome) = '')),
  'nome preservado na identidade'
);

select * from finish();
rollback;
