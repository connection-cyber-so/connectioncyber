-- Rollback de contingencia da 0046: devolve o e-mail anterior em public.users.
-- Nao remove a identidade nem toca em auth.users. Usar somente em emergencia.
begin;

update public.users
set email = 'joaquimmscoelho@gmail.com',
    updated_at = now()
where id = '61b57707-2292-49ff-8ca6-f43ccec087ed'
  and lower(email) = 'joaquimmscoelhoam@gmail.com'
  and not exists (select 1 from public.users x
                  where lower(x.email) = 'joaquimmscoelho@gmail.com'
                    and x.id <> '61b57707-2292-49ff-8ca6-f43ccec087ed');

select 'M23_HYGIENE_0046_ROLLBACK_OK' as result, now() as applied_at;

commit;
