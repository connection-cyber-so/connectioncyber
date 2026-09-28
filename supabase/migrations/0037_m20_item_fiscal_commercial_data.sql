-- ConnectionCyber — M20-G1: dados fiscais e comerciais por item do catálogo.
--
-- Ver PARECER-TECNICO-M20-G0-CADASTROS-ESTRUTURAIS-SEGMENTOS.md, seção 6, decisão 1:
-- satélite (não coluna direta em erp_catalog_items) porque (a) nem todo item emite nota
-- (service/fee/voucher), (b) o ciclo de vida fiscal muda independente do cadastro do
-- produto (reforma tributária, troca de regime), (c) permite RLS própria mais restrita
-- que o cadastro geral do catálogo.
--
-- CST/CSOSN aceitos espelham deliberadamente packages/fiscal-contract/src/tax-profiles.mjs
-- (CST, CSOSN) — se aquele arquivo mudar o universo de códigos aceitos, esta migration
-- precisa mudar junto (não há import cross-linguagem possível entre SQL e o pacote JS,
-- por isso o espelhamento é comentado nos dois lados).
--
-- Consistência entre tax_code_kind aqui e o regime tributário (CRT) do tenant continua
-- sendo responsabilidade da camada de aplicação (fiscal-contract), não uma constraint de
-- banco — o regime do tenant ainda não tem tabela própria (M13 trata isso separadamente).
begin;

create table public.erp_item_fiscal_data (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  item_id uuid not null,
  ncm text not null check (ncm ~ '^[0-9]{8}$'),
  cest text check (cest is null or cest ~ '^[0-9]{7}$'),
  origin smallint not null default 0 check (origin between 0 and 8),
  tax_code_kind text not null check (tax_code_kind in ('CST','CSOSN')),
  tax_code text not null,
  icms_rate numeric(7,4) not null default 0 check (icms_rate between 0 and 100),
  icms_base_percent numeric(7,4) not null default 100 check (icms_base_percent between 0 and 100),
  ipi_rate numeric(7,4) not null default 0 check (ipi_rate between 0 and 100),
  cst_pis text check (cst_pis is null or cst_pis ~ '^[0-9]{2}$'),
  cst_cofins text check (cst_cofins is null or cst_cofins ~ '^[0-9]{2}$'),
  fcp_rate numeric(7,4) not null default 0 check (fcp_rate between 0 and 100),
  gross_weight numeric(12,3) check (gross_weight is null or gross_weight >= 0),
  net_weight numeric(12,3) check (net_weight is null or net_weight >= 0),
  anp_code text check (anp_code is null or anp_code ~ '^[0-9]{6}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id,item_id),
  constraint erp_item_fiscal_data_tenant_id_unique unique (tenant_id,id),
  foreign key (tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete cascade,
  check (net_weight is null or gross_weight is null or gross_weight >= net_weight),
  -- espelha CST/CSOSN de packages/fiscal-contract/src/tax-profiles.mjs
  check (
    (tax_code_kind = 'CST' and tax_code in ('00','10','20','30','40','41','50','51','60','70','90'))
    or
    (tax_code_kind = 'CSOSN' and tax_code in ('101','102','103','201','202','203','300','400','500','900'))
  )
);
comment on table public.erp_item_fiscal_data is
  'Classificação fiscal por item (NCM/CEST/origem/CST-CSOSN/alíquotas/peso). Satélite de erp_catalog_items — ver M20-G0.';

create table public.erp_item_commercial_data (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  item_id uuid not null,
  cost_price numeric(19,4) not null default 0 check (cost_price >= 0),
  margin_percent numeric(7,4) not null default 0 check (margin_percent >= 0),
  suggested_sale_price numeric(19,4) check (suggested_sale_price is null or suggested_sale_price >= 0),
  min_stock_quantity numeric(19,6) not null default 0 check (min_stock_quantity >= 0),
  reorder_point numeric(19,6) check (reorder_point is null or reorder_point >= 0),
  reorder_quantity numeric(19,6) check (reorder_quantity is null or reorder_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id,item_id),
  constraint erp_item_commercial_data_tenant_id_unique unique (tenant_id,id),
  foreign key (tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete cascade,
  check (reorder_point is null or reorder_point >= min_stock_quantity)
);
comment on table public.erp_item_commercial_data is
  'Custo, margem, preço sugerido e política de reposição por item. Satélite de erp_catalog_items — ver M20-G0.';

insert into public.erp_permissions(key,name,description,category) values
('fiscal.item.read','Consultar dados fiscais do item','Consulta classificação fiscal (NCM, CST/CSOSN, alíquotas) dos itens do tenant.','Fiscal'),
('fiscal.item.manage','Gerenciar dados fiscais do item','Cria e altera classificação fiscal dos itens do tenant.','Fiscal')
on conflict (key) do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

create trigger trg_erp_item_fiscal_data_updated_at before update on public.erp_item_fiscal_data for each row execute function public.set_updated_at();
create trigger trg_erp_item_commercial_data_updated_at before update on public.erp_item_commercial_data for each row execute function public.set_updated_at();

-- RLS: fiscal tem permissão própria (fiscal.item.read/fiscal.item.manage) — mais
-- restrita que o catálogo geral, e deliberadamente distinta de fiscal.read/fiscal.*
-- da migration 0030 (M13), que governa DOCUMENTO fiscal (NF-e), não classificação de
-- ITEM — reaproveitar aquela chave sobrescreveria a descrição de uma permissão já em
-- uso por erp_tax_regimes/erp_fiscal_documents/etc. Comercial reaproveita
-- catalog.read/catalog.manage (mesmo círculo de quem já cadastra item/preço hoje).
alter table public.erp_item_fiscal_data enable row level security;
create policy erp_item_fiscal_data_select on public.erp_item_fiscal_data for select to authenticated
  using ((select erp_security.has_permission(tenant_id,'fiscal.item.read')) or (select erp_security.has_permission(tenant_id,'fiscal.item.manage')) or (select public.is_platform_staff()));
create policy erp_item_fiscal_data_insert on public.erp_item_fiscal_data for insert to authenticated
  with check ((select erp_security.has_permission(tenant_id,'fiscal.item.manage')) or (select public.is_platform_staff()));
create policy erp_item_fiscal_data_update on public.erp_item_fiscal_data for update to authenticated
  using ((select erp_security.has_permission(tenant_id,'fiscal.item.manage')) or (select public.is_platform_staff()))
  with check ((select erp_security.has_permission(tenant_id,'fiscal.item.manage')) or (select public.is_platform_staff()));

alter table public.erp_item_commercial_data enable row level security;
create policy erp_item_commercial_data_select on public.erp_item_commercial_data for select to authenticated
  using ((select erp_security.has_permission(tenant_id,'catalog.read')) or (select erp_security.has_permission(tenant_id,'catalog.manage')) or (select public.is_platform_staff()));
create policy erp_item_commercial_data_insert on public.erp_item_commercial_data for insert to authenticated
  with check ((select erp_security.has_permission(tenant_id,'catalog.manage')) or (select public.is_platform_staff()));
create policy erp_item_commercial_data_update on public.erp_item_commercial_data for update to authenticated
  using ((select erp_security.has_permission(tenant_id,'catalog.manage')) or (select public.is_platform_staff()))
  with check ((select erp_security.has_permission(tenant_id,'catalog.manage')) or (select public.is_platform_staff()));

revoke all on table public.erp_item_fiscal_data, public.erp_item_commercial_data from anon,authenticated;
grant select,insert,update on table public.erp_item_fiscal_data, public.erp_item_commercial_data to authenticated;
grant all on table public.erp_item_fiscal_data, public.erp_item_commercial_data to service_role;

commit;
