-- 0064 · Ordens de produção ligadas à ficha técnica (erp_item_compositions)
-- Escopo desta migration:
--   1) erp_production_orders: ordem de produção (status draft | cancelled), com ficha, item, quantidade e unidade.
--   2) erp_production_order_requirements: visão somente leitura com a necessidade de insumos por ordem em rascunho.
-- FORA deste gate (próximo gate, com preflight/testes/rollback próprios):
--   - baixa de estoque (movimentos production/consumption em erp_stock_movements + erp_stock_movement_items)
--   - status 'posted'
-- Decisões desta versão:
--   - Rendimento vem de erp_item_compositions.yield_quantity / yield_unit_id.
--     erp_recipe_yields (versionado por vigência) fica para um gate futuro, para não haver duas fontes de verdade agora.
--   - Tipos de ficha aceitos: recipe, bill_of_materials. Kits não geram ordem nesta versão.
--   - Unidade da ordem = unidade de rendimento da ficha (sem conversão automática nesta versão).
--   - Fórmula: necessidade = linha.quantity * (ordem.quantity / ficha.yield_quantity) * (1 + linha.loss_percent / 100)

-- 1) Tabela de ordens
create table public.erp_production_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  establishment_id uuid not null,
  item_id uuid not null,
  composition_id uuid not null,
  unit_id uuid not null,
  quantity numeric not null,
  status text not null default 'draft',
  idempotency_key text not null,
  planned_for timestamptz,
  cancelled_at timestamptz,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_production_orders_tenant_id_id_key unique (tenant_id, id),
  constraint erp_production_orders_tenant_idempotency_key unique (tenant_id, idempotency_key),
  constraint erp_production_orders_establishment_fk
    foreign key (tenant_id, establishment_id) references public.erp_establishments (tenant_id, id) on delete restrict,
  constraint erp_production_orders_item_fk
    foreign key (tenant_id, item_id) references public.erp_catalog_items (tenant_id, id) on delete restrict,
  constraint erp_production_orders_composition_fk
    foreign key (tenant_id, composition_id) references public.erp_item_compositions (tenant_id, id) on delete restrict,
  constraint erp_production_orders_unit_fk
    foreign key (tenant_id, unit_id) references public.erp_units (tenant_id, id) on delete restrict,
  constraint erp_production_orders_quantity_check check (quantity > 0),
  constraint erp_production_orders_status_check check (status in ('draft', 'cancelled')),
  constraint erp_production_orders_status_dates_check check (
    (status = 'draft' and cancelled_at is null)
    or (status = 'cancelled' and cancelled_at is not null)
  ),
  constraint erp_production_orders_idempotency_key_check check (length(idempotency_key) >= 8)
);

create index erp_production_orders_status_idx
  on public.erp_production_orders (tenant_id, establishment_id, status, planned_for);

-- 2) Consistência entre ordem e ficha
create or replace function public.erp_production_orders_check_ficha()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item uuid;
  v_yield_unit uuid;
  v_active boolean;
  v_kind text;
begin
  select c.item_id, c.yield_unit_id, c.active, c.kind
    into v_item, v_yield_unit, v_active, v_kind
    from public.erp_item_compositions c
   where c.tenant_id = new.tenant_id
     and c.id = new.composition_id;

  if v_item is distinct from new.item_id then
    raise exception 'erp_production_orders: a ficha nao pertence ao item produzido'
      using errcode = '23514';
  end if;

  if v_kind not in ('recipe', 'bill_of_materials') then
    raise exception 'erp_production_orders: ficha do tipo % nao gera ordem de producao', v_kind
      using errcode = '23514';
  end if;

  if not v_active then
    raise exception 'erp_production_orders: ficha inativa'
      using errcode = '23514';
  end if;

  if v_yield_unit is distinct from new.unit_id then
    raise exception 'erp_production_orders: a unidade da ordem deve ser a unidade de rendimento da ficha'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function public.erp_production_orders_check_ficha() from public, anon, authenticated;

create trigger erp_production_orders_check_ficha_trg
  before insert or update of composition_id, item_id, unit_id on public.erp_production_orders
  for each row execute function public.erp_production_orders_check_ficha();

-- 3) RLS: leitura por stock.read (ou stock.manage / stock.count / staff); escrita por stock.manage (ou staff). Sem DELETE.
alter table public.erp_production_orders enable row level security;

create policy erp_production_orders_select on public.erp_production_orders
  for select to authenticated
  using (
    (select erp_security.has_permission(tenant_id, 'stock.read'))
    or (select erp_security.has_permission(tenant_id, 'stock.manage'))
    or (select erp_security.has_permission(tenant_id, 'stock.count'))
    or (select public.is_platform_staff())
  );

create policy erp_production_orders_insert on public.erp_production_orders
  for insert to authenticated
  with check (
    (select erp_security.has_permission(tenant_id, 'stock.manage'))
    or (select public.is_platform_staff())
  );

create policy erp_production_orders_update on public.erp_production_orders
  for update to authenticated
  using (
    (select erp_security.has_permission(tenant_id, 'stock.manage'))
    or (select public.is_platform_staff())
  )
  with check (
    (select erp_security.has_permission(tenant_id, 'stock.manage'))
    or (select public.is_platform_staff())
  );

revoke all on public.erp_production_orders from anon;
grant select, insert, update on public.erp_production_orders to authenticated;

-- 4) Necessidade de insumos por ordem em rascunho (somente leitura; respeita RLS de quem consulta)
create view public.erp_production_order_requirements
with (security_invoker = true) as
select
  o.tenant_id,
  o.id as production_order_id,
  o.establishment_id,
  o.item_id as produced_item_id,
  l.component_item_id,
  l.component_variant_id,
  l.unit_id as component_unit_id,
  round(l.quantity * (o.quantity / c.yield_quantity) * (1 + l.loss_percent / 100), 4) as required_quantity
from public.erp_production_orders o
join public.erp_item_compositions c
  on c.tenant_id = o.tenant_id and c.id = o.composition_id
join public.erp_item_composition_lines l
  on l.tenant_id = c.tenant_id and l.composition_id = c.id
where o.status = 'draft';

revoke all on public.erp_production_order_requirements from anon;
grant select on public.erp_production_order_requirements to authenticated;
