-- 0061_storefront_permission_rpc.sql
-- Data: 2026-11-07
-- Origem: vitrine multi-tenant (apps/storefront). Permite à vitrine checar permissão do ERP
--   (membership ativa + papel + permissão) sem ler profiles legado.
-- Regras (fail-closed):
--   - sem auth.uid() → false;
--   - tenant inativo → false;
--   - demais casos: erp_security.has_permission(tenant, permissão).
-- Só leitura de decisão: não altera dados.
-- Reversão: supabase/rollback/0061_storefront_permission_rpc.rollback.sql

create or replace function public.storefront_has_permission(p_tenant_id uuid, p_permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    auth.uid() is not null
    and p_tenant_id is not null
    and p_permission_key is not null
    and exists (select 1 from public.tenants t where t.id = p_tenant_id and t.ativo)
    and erp_security.has_permission(p_tenant_id, p_permission_key);
$$;

revoke all on function public.storefront_has_permission(uuid, text) from public;
revoke all on function public.storefront_has_permission(uuid, text) from anon;
grant execute on function public.storefront_has_permission(uuid, text) to authenticated;
