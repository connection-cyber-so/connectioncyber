-- ConnectionCyber — M04-G1 — rollback destrutivo SOMENTE para laboratório
--
-- NÃO executar em Supabase staging ou produção. Correções remotas são forward-fix.
-- Confirmações obrigatórias na mesma sessão:
--   set app.execution_environment = 'LOCAL-DISCARDABLE-LAB';
--   set app.m04_rollback_confirmation = 'DROP-M04-WITHOUT-IDENTITY-DATA';

begin;

do $$
declare
  run_count bigint;
  step_count bigint;
  nullable_profiles bigint;
  protected_role_count bigint;
  protected_membership_count bigint;
  permission_use_count bigint;
begin
  if current_setting('app.execution_environment', true)
       is distinct from 'LOCAL-DISCARDABLE-LAB'
     or current_setting('app.m04_rollback_confirmation', true)
       is distinct from 'DROP-M04-WITHOUT-IDENTITY-DATA' then
    raise exception 'M04_ROLLBACK_BLOCKED: confirmações explícitas ausentes.';
  end if;

  select count(*) into run_count from public.erp_identity_provisioning_runs;
  select count(*) into step_count from public.erp_identity_provisioning_steps;
  select count(*) into nullable_profiles from public.users where tenant_id is null;
  select count(*) into protected_role_count
  from public.erp_roles where requires_mfa or sensitivity <> 'standard';
  select count(*) into protected_membership_count
  from public.erp_tenant_memberships
  where invited_at is not null or activated_at is not null or suspended_at is not null
     or revoked_at is not null or invitation_expires_at is not null;
  select count(*) into permission_use_count
  from public.erp_role_permissions role_permission
  join public.erp_permissions permission on permission.id = role_permission.permission_id
  where permission.key in (
    'identities.read', 'identities.manage', 'roles.assign', 'mfa.read', 'mfa.enforce'
  );

  if run_count <> 0 or step_count <> 0 or nullable_profiles <> 0
     or protected_role_count <> 0 or protected_membership_count <> 0
     or permission_use_count <> 0 then
    raise exception
      'M04_ROLLBACK_BLOCKED: runs %, steps %, profiles sem tenant %, roles protegidas %, memberships com lifecycle %, permissões em uso %.',
      run_count, step_count, nullable_profiles, protected_role_count,
      protected_membership_count, permission_use_count;
  end if;
end
$$;

drop function if exists erp_security.has_permission_at_aal(uuid, text, text);
drop function if exists erp_security.current_aal();
drop table if exists public.erp_identity_provisioning_steps;
drop table if exists public.erp_identity_provisioning_runs;

delete from public.erp_permissions
where key in ('identities.read', 'identities.manage', 'roles.assign', 'mfa.read', 'mfa.enforce');

alter table public.erp_roles
  drop column if exists sensitivity,
  drop column if exists requires_mfa;

alter table public.erp_tenant_memberships
  drop constraint if exists erp_membership_invitation_period_valid,
  drop column if exists invitation_expires_at,
  drop column if exists revoked_at,
  drop column if exists suspended_at,
  drop column if exists activated_at,
  drop column if exists invited_at;

drop policy if exists users_select_self on public.users;
drop policy if exists users_update_self_profile on public.users;

create policy "usuário vê o próprio perfil"
  on public.users for select
  using (auth.uid() = id);
create policy "usuário atualiza o próprio perfil"
  on public.users for update
  using (auth.uid() = id);

grant select, insert, update, delete on table public.users to authenticated;
alter table public.users alter column tenant_id set not null;

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
  meta_tenant_id := nullif(new.raw_user_meta_data->>'tenant_id', '')::uuid;
  if meta_tenant_id is null then
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
  from public.users where id = (event->>'user_id')::uuid;
  claims := event->'claims';
  if user_tenant_id is not null then
    claims := jsonb_set(claims, '{app_metadata,tenant_id}', to_jsonb(user_tenant_id));
  end if;
  return jsonb_set(event, '{claims}', claims);
end;
$$;

create or replace function public.current_tenant_id()
returns uuid
language sql stable security definer set search_path = public
as $$
  select tenant_id from public.users where id = auth.uid()
$$;

grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, anon, public;

commit;
