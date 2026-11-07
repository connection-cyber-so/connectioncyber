-- Rollback 0062. Só executar se erp_food_fulfillments NÃO tiver linhas com status 'failed' ou courier_party_id preenchido.
-- Se já houver dados reais, prefira forward-fix (regra do projeto: rollback destrutivo só em laboratório).

begin;

-- 1) Zonas de taxa
drop trigger if exists erp_delivery_fee_zones_no_overlap_trg on public.erp_delivery_fee_zones;
drop function if exists public.erp_delivery_fee_zones_no_overlap();
drop table if exists public.erp_delivery_fee_zones;

-- 2) Status 'failed' e motivo
alter table public.erp_food_fulfillments drop constraint if exists erp_food_fulfillments_failure_reason_check;
alter table public.erp_food_fulfillments drop constraint if exists erp_food_fulfillments_status_check;
alter table public.erp_food_fulfillments
  add constraint erp_food_fulfillments_status_check
    check (status = any (array['pending', 'ready', 'in_transit', 'delivered', 'cancelled']));

-- 3) Colunas novas
alter table public.erp_food_fulfillments
  drop constraint if exists erp_food_fulfillments_courier_kind_check,
  drop constraint if exists erp_food_fulfillments_courier_party_fk,
  drop constraint if exists erp_food_fulfillments_attempts_check,
  drop constraint if exists erp_food_fulfillments_distance_check,
  drop constraint if exists erp_food_fulfillments_fee_check,
  drop constraint if exists erp_food_fulfillments_fee_mode_check;

alter table public.erp_food_fulfillments
  drop column if exists courier_kind,
  drop column if exists courier_party_id,
  drop column if exists courier_name,
  drop column if exists attempts,
  drop column if exists failure_reason,
  drop column if exists failed_at,
  drop column if exists distance_km,
  drop column if exists delivery_fee,
  drop column if exists fee_charge_mode;

commit;
