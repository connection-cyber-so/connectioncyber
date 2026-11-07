-- Rollback 0064. Só executar se erp_production_orders NÃO tiver linhas com dados reais.
-- Se já houver ordens reais, prefira forward-fix (regra do projeto: rollback destrutivo só em laboratório).

begin;

drop view if exists public.erp_production_order_requirements;
drop trigger if exists erp_production_orders_check_ficha_trg on public.erp_production_orders;
drop function if exists public.erp_production_orders_check_ficha();
drop table if exists public.erp_production_orders;

commit;
