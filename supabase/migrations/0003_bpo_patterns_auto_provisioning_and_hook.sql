-- =========================================================================
-- ConnectionCyberSO — Padrões trazidos da auditoria multi-projeto
-- (docs/auditoria-ecossistema-connectioncyberos.md, itens 1 e 2)
--
-- 1. Trigger de auto-provisionamento: cria public.users automaticamente
--    quando alguém se cadastra via Supabase Auth. Sem isso, um signup fica
--    "solto" (existe em auth.users, mas não em public.users, e todo o
--    modelo multi-tenant depende de public.users.tenant_id).
-- 2. Custom Access Token Hook: grava tenant_id no app_metadata do JWT na
--    emissão do token. A FUNÇÃO fica pronta aqui, mas a ATIVAÇÃO como hook
--    ativo do projeto é um passo manual no Dashboard (Authentication ->
--    Hooks) — não existe comando de CLI para isso em projeto hospedado.
--    Enquanto não for ativada, current_tenant_id() continua funcionando
--    exatamente como antes (via subquery) — nada quebra.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1. Auto-provisionamento de public.users
-- -------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta_tenant_id uuid;
  default_tenant_id uuid;
begin
  -- tenant explícito no metadata do signup (ex: convite de um tenant específico)
  meta_tenant_id := nullif(new.raw_user_meta_data->>'tenant_id', '')::uuid;

  if meta_tenant_id is null then
    -- fallback: tenant ConnectionCyber (signup público hoje só existe no site institucional)
    select id into default_tenant_id from public.tenants where slug = 'connectioncyber';
  end if;

  insert into public.users (id, nome, email, tenant_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(meta_tenant_id, default_tenant_id)
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Cria a linha correspondente em public.users assim que auth.users recebe um novo usuário. Sem tenant explícito no metadata, cai no tenant ConnectionCyber.';

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();

-- -------------------------------------------------------------------------
-- 2. Custom Access Token Hook — função pronta, ativação pendente (Dashboard)
-- -------------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  claims jsonb;
  user_tenant_id uuid;
begin
  select tenant_id into user_tenant_id
  from public.users
  where id = (event->>'user_id')::uuid;

  claims := event->'claims';

  if user_tenant_id is not null then
    claims := jsonb_set(claims, '{app_metadata,tenant_id}', to_jsonb(user_tenant_id));
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

comment on function public.custom_access_token_hook(jsonb) is
  'Grava tenant_id no app_metadata do JWT na emissão do token. PRECISA ser habilitada manualmente em Authentication > Hooks > Custom Access Token no Dashboard do Supabase para entrar em vigor — a função existir aqui não ativa o hook sozinha.';

grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, anon, public;
