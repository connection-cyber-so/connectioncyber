-- 0063 · PDV · políticas fiscais e de desconto
-- Escopo:
--   1) erp_catalog_items: flags tipadas age_restricted (+18) e fumigeno, com regras de consistência.
--   2) erp_discount_authorizations: alçada de desconto acima do limite automático (registro da autorização).
--   3) Seed de configurações por tenant em erp_tenant_settings (chaves operacionais do PDV).
-- Decisões aprovadas (07/11/2026):
--   - Flags +18 e fumígeno como colunas tipadas.
--   - Fumígeno exige +18 e não pode ser vendido fracionado.
--   - Limite de desconto sem autorização: 5% por padrão, configurável por tenant (não automático).
--   - NFC-e por canal configurável; padrão: balcão emite, app/site/iFood não emitem automaticamente.
--   - Sangria e fechamento usam as permissões cash.adjust e cash.close (já existentes).
-- Fora deste gate: validação de aprovador por membership (será feita por RPC dedicada), alçada para sangria/fechamento.

-- 1) Flags tipadas no catálogo
alter table public.erp_catalog_items
  add column if not exists age_restricted boolean not null default false,
  add column if not exists fumigeno boolean not null default false;

alter table public.erp_catalog_items
  add constraint erp_catalog_items_fumigeno_requires_age_check
    check (not fumigeno or age_restricted),
  add constraint erp_catalog_items_fumigeno_no_fraction_check
    check (not (fumigeno and allows_fraction));

-- 2) Alçada de desconto
create table public.erp_discount_authorizations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  establishment_id uuid not null,
  sale_id uuid,
  requested_by uuid not null,
  approved_by uuid not null,
  discount_amount numeric(12,2) not null,
  discount_percent numeric(6,2) not null,
  limit_percent numeric(6,2) not null,
  reason text not null,
  created_at timestamptz not null default now(),
  constraint erp_discount_authorizations_tenant_id_id_key unique (tenant_id, id),
  constraint erp_discount_authorizations_establishment_fk
    foreign key (tenant_id, establishment_id) references public.erp_establishments (tenant_id, id) on delete restrict,
  constraint erp_discount_authorizations_sale_fk
    foreign key (tenant_id, sale_id) references public.erp_sales (tenant_id, id) on delete restrict,
  constraint erp_discount_authorizations_amount_check check (discount_amount > 0),
  constraint erp_discount_authorizations_percent_check check (discount_percent > 0 and discount_percent <= 100),
  constraint erp_discount_authorizations_limit_check check (limit_percent >= 0 and limit_percent <= 100),
  constraint erp_discount_authorizations_above_limit_check check (discount_percent > limit_percent),
  constraint erp_discount_authorizations_reason_check check (length(btrim(reason)) >= 3),
  constraint erp_discount_authorizations_separation_check check (approved_by <> requested_by)
);

create index erp_discount_authorizations_sale_idx
  on public.erp_discount_authorizations (tenant_id, establishment_id, created_at);

alter table public.erp_discount_authorizations enable row level security;

create policy erp_discount_authorizations_select on public.erp_discount_authorizations
  for select to authenticated
  using (
    (select erp_security.has_permission(tenant_id, 'sales.discount'))
    or (select erp_security.has_permission(tenant_id, 'sales.read'))
    or (select public.is_platform_staff())
  );

-- A sessão que grava é a do aprovador: approved_by precisa ser o usuário autenticado e ter sales.discount.
create policy erp_discount_authorizations_insert on public.erp_discount_authorizations
  for insert to authenticated
  with check (
    approved_by = (select auth.uid())
    and (
      (select erp_security.has_permission(tenant_id, 'sales.discount'))
      or (select public.is_platform_staff())
    )
  );

revoke all on public.erp_discount_authorizations from anon;
grant select, insert on public.erp_discount_authorizations to authenticated;

-- 3) Configurações operacionais padrão por tenant (idempotente)
insert into public.erp_tenant_settings (tenant_id, establishment_id, key, value, sensitivity, schema_version)
select t.id, null, k.key, k.value, 'internal', 1
  from public.tenants t
 cross join (values
   ('pdv.discount.auto_limit_percent', '{"percent": 5}'::jsonb),
   ('pdv.fiscal.emit_nfce_by_channel', '{"balcao": true, "app": false, "site": false, "ifood": false}'::jsonb),
   ('pdv.kitchen.print_on_accept', '{"enabled": true}'::jsonb)
 ) as k(key, value)
 where not exists (
   select 1 from public.erp_tenant_settings s
    where s.tenant_id = t.id and s.key = k.key and s.establishment_id is null
 );
