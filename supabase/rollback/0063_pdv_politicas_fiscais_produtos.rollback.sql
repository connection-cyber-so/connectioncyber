-- Rollback 0063. Só executar se erp_discount_authorizations NÃO tiver dados reais.
-- Se já houver autorizações reais, prefira forward-fix (regra do projeto: rollback destrutivo só em laboratório).
-- Settings: só remova as chaves se nenhum tenant as tiver alterado manualmente.

begin;

drop table if exists public.erp_discount_authorizations;

alter table public.erp_catalog_items
  drop constraint if exists erp_catalog_items_fumigeno_no_fraction_check,
  drop constraint if exists erp_catalog_items_fumigeno_requires_age_check;

alter table public.erp_catalog_items
  drop column if exists fumigeno,
  drop column if exists age_restricted;

delete from public.erp_tenant_settings
 where establishment_id is null
   and key in ('pdv.discount.auto_limit_percent', 'pdv.fiscal.emit_nfce_by_channel', 'pdv.kitchen.print_on_accept');

commit;
