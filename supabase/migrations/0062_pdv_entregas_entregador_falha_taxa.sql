-- 0062 · PDV · entregas: entregador, falha de entrega, taxa e zonas por raio
-- Aprovado pelo responsável em 07/11/2026 (decisões G2, G3, G9 do mapeamento PDV → erp_*).
-- Tabela erp_food_fulfillments tinha 0 linhas no staging quando esta migration foi escrita.
-- Preflight: supabase/preflight/0062_pdv_entregas_entregador_falha_taxa_preflight.sql
-- Testes:    supabase/tests/0062_pdv_entregas_entregador_falha_taxa.test.sql
-- Rollback:  supabase/rollback/0062_pdv_entregas_entregador_falha_taxa.rollback.sql

-- 1) Entregador, falha e taxa em erp_food_fulfillments (G2, G3, G9)
alter table public.erp_food_fulfillments
  add column if not exists courier_kind text,
  add column if not exists courier_party_id uuid,
  add column if not exists courier_name text,
  add column if not exists attempts integer not null default 0,
  add column if not exists failure_reason text,
  add column if not exists failed_at timestamptz,
  add column if not exists distance_km numeric(8,2),
  add column if not exists delivery_fee numeric(12,2) not null default 0,
  add column if not exists fee_charge_mode text not null default 'in_sale';

alter table public.erp_food_fulfillments
  add constraint erp_food_fulfillments_courier_kind_check
    check (courier_kind is null or courier_kind in ('own', 'platform')),
  add constraint erp_food_fulfillments_courier_party_fk
    foreign key (tenant_id, courier_party_id) references public.erp_parties (tenant_id, id) on delete restrict,
  add constraint erp_food_fulfillments_attempts_check
    check (attempts >= 0),
  add constraint erp_food_fulfillments_distance_check
    check (distance_km is null or distance_km >= 0),
  add constraint erp_food_fulfillments_fee_check
    check (delivery_fee >= 0),
  add constraint erp_food_fulfillments_fee_mode_check
    check (fee_charge_mode in ('in_sale', 'on_delivery', 'free'));

-- 2) Novo status 'failed' (falha de entrega, com motivo obrigatório)
alter table public.erp_food_fulfillments drop constraint erp_food_fulfillments_status_check;
alter table public.erp_food_fulfillments
  add constraint erp_food_fulfillments_status_check
    check (status = any (array['pending', 'ready', 'in_transit', 'delivered', 'cancelled', 'failed'])),
  add constraint erp_food_fulfillments_failure_reason_check
    check (status <> 'failed' or (failure_reason is not null and failed_at is not null));

-- 3) Zonas de taxa por raio (cadastro por estabelecimento)
create table if not exists public.erp_delivery_fee_zones (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  establishment_id uuid not null,
  radius_from_km numeric(8,2) not null,
  radius_to_km numeric(8,2) not null,
  fee_amount numeric(12,2) not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_delivery_fee_zones_tenant_id_id_key unique (tenant_id, id),
  constraint erp_delivery_fee_zones_establishment_fk
    foreign key (tenant_id, establishment_id) references public.erp_establishments (tenant_id, id) on delete cascade,
  constraint erp_delivery_fee_zones_radius_check
    check (radius_from_km >= 0 and radius_to_km > radius_from_km),
  constraint erp_delivery_fee_zones_fee_check
    check (fee_amount >= 0)
);

create index if not exists erp_delivery_fee_zones_lookup_idx
  on public.erp_delivery_fee_zones (tenant_id, establishment_id, active, radius_from_km);

-- Faixas ativas do mesmo estabelecimento não podem se sobrepor (intervalo [from, to))
create or replace function public.erp_delivery_fee_zones_no_overlap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.active and exists (
    select 1
      from public.erp_delivery_fee_zones z
     where z.tenant_id = new.tenant_id
       and z.establishment_id = new.establishment_id
       and z.active
       and z.id <> new.id
       and z.radius_from_km < new.radius_to_km
       and new.radius_from_km < z.radius_to_km
  ) then
    raise exception 'erp_delivery_fee_zones: faixa de raio sobrepoe outra zona ativa do estabelecimento'
      using errcode = '23P01';
  end if;
  return new;
end;
$$;

revoke all on function public.erp_delivery_fee_zones_no_overlap() from public, anon, authenticated;

create trigger erp_delivery_fee_zones_no_overlap_trg
  before insert or update on public.erp_delivery_fee_zones
  for each row execute function public.erp_delivery_fee_zones_no_overlap();

alter table public.erp_delivery_fee_zones enable row level security;

create policy erp_delivery_fee_zones_select on public.erp_delivery_fee_zones
  for select to authenticated
  using ((select erp_security.has_permission(tenant_id, 'food.read')) or (select public.is_platform_staff()));

create policy erp_delivery_fee_zones_insert on public.erp_delivery_fee_zones
  for insert to authenticated
  with check ((select erp_security.has_permission(tenant_id, 'food.manage')) or (select public.is_platform_staff()));

create policy erp_delivery_fee_zones_update on public.erp_delivery_fee_zones
  for update to authenticated
  using ((select erp_security.has_permission(tenant_id, 'food.manage')) or (select public.is_platform_staff()))
  with check ((select erp_security.has_permission(tenant_id, 'food.manage')) or (select public.is_platform_staff()));

create policy erp_delivery_fee_zones_delete on public.erp_delivery_fee_zones
  for delete to authenticated
  using ((select erp_security.has_permission(tenant_id, 'food.manage')) or (select public.is_platform_staff()));

revoke all on public.erp_delivery_fee_zones from anon;
grant select, insert, update, delete on public.erp_delivery_fee_zones to authenticated;
