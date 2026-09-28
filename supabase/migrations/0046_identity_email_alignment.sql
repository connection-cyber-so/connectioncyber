-- M23 0.1.0 (higiene de identidade): additive; apply only after preflight.
-- public.users.email nao acompanha trocas de e-mail feitas no Auth (so existe hook
-- de INSERT, da migration 0003/0018). Alinha a identidade divergente do usuario
-- 61b57707 ao e-mail vigente em auth.users, preservando nome, tenant e demais
-- colunas. Idempotente e nao destrutivo.
begin;

update public.users w
set email = lower(a.email),
    updated_at = now()
from auth.users a
where a.id = w.id
  and w.id = '61b57707-2292-49ff-8ca6-f43ccec087ed'
  and a.email is not null
  and btrim(a.email) <> ''
  and w.email is distinct from lower(a.email)
  and not exists (select 1 from public.users x where x.email = lower(a.email));

commit;
