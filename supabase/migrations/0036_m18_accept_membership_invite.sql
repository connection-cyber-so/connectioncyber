-- ConnectionCyber - M18-G22: fecha o ultimo elo que faltava do fluxo de convite. Ate
-- aqui, nada no sistema fazia erp_tenant_memberships sair de 'invited' pra 'active' -
-- mesmo com login funcionando de verdade (email+senha OK, sessao OK), decidePortalAccess
-- (isMembershipActive) exige status='active' e devolveria 'forbidden' pra sempre.
begin;

create or replace function public.erp_accept_pending_memberships_v1()
returns setof uuid
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'authentication required'; end if;
  return query
    update public.erp_tenant_memberships
      set status = 'active', updated_at = now()
      where user_id = auth.uid() and status = 'invited'
      returning id;
end $$;

comment on function public.erp_accept_pending_memberships_v1() is
  'Ativa todas as memberships invited do usuario autenticado (auth.uid()). Sempre escopado a si mesmo - nao recebe parametro, nao pode ativar membership de outro usuario.';

revoke execute on function public.erp_accept_pending_memberships_v1() from public, anon;
grant execute on function public.erp_accept_pending_memberships_v1() to authenticated, service_role;

commit;
