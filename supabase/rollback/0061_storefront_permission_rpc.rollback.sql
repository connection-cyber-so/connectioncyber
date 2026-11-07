-- Rollback 0061: remove a função da vitrine. Não afeta dados nem erp_security.
drop function if exists public.storefront_has_permission(uuid, text);
