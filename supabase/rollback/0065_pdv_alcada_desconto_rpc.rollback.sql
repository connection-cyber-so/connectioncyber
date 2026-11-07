-- Rollback 0065: volta ao estado da 0063 (insert direto permitido e sem a RPC).
-- Só executar se a RPC não tiver autorizações reais que precisem de rastreio. Se houver, prefira forward-fix.

begin;

drop function if exists public.erp_authorize_discount(uuid, uuid, uuid, uuid, numeric, numeric, text);

create policy erp_discount_authorizations_insert on public.erp_discount_authorizations
  for insert to authenticated
  with check (
    approved_by = (select auth.uid())
    and (
      (select erp_security.has_permission(tenant_id, 'sales.discount'))
      or (select public.is_platform_staff())
    )
  );

grant insert on public.erp_discount_authorizations to authenticated;

commit;
