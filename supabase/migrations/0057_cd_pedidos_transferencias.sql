-- 0057_cd_pedidos_transferencias.sql
-- Data: 2026-11-06
-- Origem: M54-G3. Pedidos do CD, transferências loja → CD, reservas e regras de saída.
-- Decisões (aprovadas em 06/11/2026): limite automático 50 un. ou R$ 2.000 decide 'autorizada'
--   ou 'aguardando_aprovacao'; falta vira transferência automática loja → CD ligada ao pedido;
--   baixa no CD na coleta (coletado_em) e na loja no despacho (despachado_em);
--   canal web usa ['cd','loja']; balcão e Shopee usam ['loja'].
-- Escopo: tabelas, checks, triggers de tipo de local e RLS somente SELECT (membership ou staff).
--   Escrita fica para RPC security definer em M54-G4.
-- Fora de escopo: alocação de reserva (G4), dados FICTICIO (G4), catálogo de produtos (produto_id sem FK).
-- Reversão: supabase/rollback/0057_cd_pedidos_transferencias.rollback.sql (só com tabelas vazias).

-- 1) Configuração do CD por tenant
create table if not exists public.cd_configuracoes (
  tenant_id            uuid primary key references public.tenants(id) on delete restrict,
  limite_automatico_qtd    integer not null default 50 check (limite_automatico_qtd > 0),
  limite_automatico_valor  numeric(12,2) not null default 2000.00 check (limite_automatico_valor > 0),
  politica_falta      text not null default 'transferencia_automatica' check (politica_falta in ('transferencia_automatica', 'bloquear')),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- 2) Regras de saída: de qual local sair, por canal, em ordem de prioridade
create table if not exists public.regras_saida (
  tenant_id     uuid not null references public.tenants(id) on delete restrict,
  canal         text not null check (canal in ('web', 'balcao', 'shopee')),
  prioridade    integer not null check (prioridade > 0),
  local_tipo    text not null check (local_tipo in ('cd', 'loja')),
  created_at    timestamptz not null default now(),
  primary key (tenant_id, canal, prioridade),
  constraint regras_saida_canal_local_unico unique (tenant_id, canal, local_tipo)
);

-- 3) Pedidos do CD (saída do CD ou da loja via canal)
create table if not exists public.pedidos_cd (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references public.tenants(id) on delete restrict,
  local_id            uuid not null,
  canal               text not null check (canal in ('web', 'balcao', 'shopee')),
  status              text not null default 'aguardando_aprovacao'
    check (status in ('aguardando_aprovacao', 'autorizada', 'em_separacao', 'coletado', 'despachado', 'cancelado')),
  total_qtd           integer not null default 0 check (total_qtd >= 0),
  total_valor         numeric(12,2) not null default 0 check (total_valor >= 0),
  autorizada_em       timestamptz,
  coletado_em         timestamptz,
  despachado_em       timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint pedidos_cd_local_fk foreign key (tenant_id, local_id)
    references public.locais(tenant_id, id) on delete restrict,
  constraint pedidos_cd_tenant_id_unique unique (tenant_id, id),
  constraint pedidos_cd_coleta_exige_autorizacao check (coletado_em is null or autorizada_em is not null)
);

create table if not exists public.pedidos_cd_itens (
  tenant_id     uuid not null,
  pedido_cd_id  uuid not null,
  produto_id    uuid not null,  -- SEM FK: catálogo de produtos pendente
  qtd           integer not null check (qtd > 0),
  preco_unit    numeric(12,2) not null check (preco_unit >= 0),
  primary key (tenant_id, pedido_cd_id, produto_id),
  constraint pedidos_cd_itens_pedido_fk foreign key (tenant_id, pedido_cd_id)
    references public.pedidos_cd(tenant_id, id) on delete restrict
);

-- 4) Transferências entre locais (loja → CD)
create table if not exists public.transferencias (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references public.tenants(id) on delete restrict,
  origem_local_id  uuid not null,
  destino_local_id uuid not null,
  pedido_cd_id     uuid,
  status           text not null default 'pendente' check (status in ('pendente', 'despachada', 'recebida', 'cancelada')),
  despachado_em   timestamptz,
  recebido_em     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint transferencias_origem_fk foreign key (tenant_id, origem_local_id)
    references public.locais(tenant_id, id) on delete restrict,
  constraint transferencias_destino_fk foreign key (tenant_id, destino_local_id)
    references public.locais(tenant_id, id) on delete restrict,
  constraint transferencias_pedido_fk foreign key (tenant_id, pedido_cd_id)
    references public.pedidos_cd(tenant_id, id) on delete restrict,
  constraint transferencias_origem_diferente_destino check (origem_local_id <> destino_local_id),
  constraint transferencias_tenant_id_unique unique (tenant_id, id),
  constraint transferencias_despacho_exige_timestamp check (status <> 'despachada' or despachado_em is not null)
);

create table if not exists public.transferencia_itens (
  tenant_id       uuid not null,
  transferencia_id uuid not null,
  produto_id      uuid not null,  -- SEM FK: catálogo de produtos pendente
  qtd             integer not null check (qtd > 0),
  primary key (tenant_id, transferencia_id, produto_id),
  constraint transferencia_itens_fk foreign key (tenant_id, transferencia_id)
    references public.transferencias(tenant_id, id) on delete restrict
);

-- 5) Reservas: quantidade reservada de um produto em um endereço, para um pedido
create table if not exists public.reservas (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants(id) on delete restrict,
  pedido_cd_id  uuid not null,
  produto_id    uuid not null,  -- SEM FK: catálogo de produtos pendente
  endereco_id   uuid not null,
  qtd           integer not null check (qtd > 0),
  status        text not null default 'ativa' check (status in ('ativa', 'consumida', 'liberada')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint reservas_pedido_fk foreign key (tenant_id, pedido_cd_id)
    references public.pedidos_cd(tenant_id, id) on delete restrict,
  constraint reservas_endereco_fk foreign key (tenant_id, endereco_id)
    references public.enderecos(tenant_id, id) on delete restrict
);

-- Tipo de local: pedido do CD sai de local tipo 'cd'; transferência vai de 'loja' para 'cd'.
create or replace function public.cd_valida_tipos_locais()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_tipo_origem text;
  v_tipo_destino text;
begin
  if tg_table_name = 'pedidos_cd' then
    select l.tipo into v_tipo_origem from public.locais l where l.tenant_id = new.tenant_id and l.id = new.local_id;
    if v_tipo_origem is distinct from 'cd' then
      raise exception 'pedido do CD só pode sair de local do tipo cd';
    end if;
  elsif tg_table_name = 'transferencias' then
    select l.tipo into v_tipo_origem from public.locais l where l.tenant_id = new.tenant_id and l.id = new.origem_local_id;
    select l.tipo into v_tipo_destino from public.locais l where l.tenant_id = new.tenant_id and l.id = new.destino_local_id;
    if v_tipo_origem is distinct from 'loja' or v_tipo_destino is distinct from 'cd' then
      raise exception 'transferência só pode ir de loja para cd';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_pedidos_cd_tipo_local on public.pedidos_cd;
create trigger trg_pedidos_cd_tipo_local before insert or update on public.pedidos_cd
  for each row execute function public.cd_valida_tipos_locais();
drop trigger if exists trg_transferencias_tipo_local on public.transferencias;
create trigger trg_transferencias_tipo_local before insert or update on public.transferencias
  for each row execute function public.cd_valida_tipos_locais();

-- updated_at automático (reutiliza função da 0055)
drop trigger if exists trg_cd_configuracoes_updated_at on public.cd_configuracoes;
create trigger trg_cd_configuracoes_updated_at before update on public.cd_configuracoes
  for each row execute function public.cd_set_updated_at();
drop trigger if exists trg_pedidos_cd_updated_at on public.pedidos_cd;
create trigger trg_pedidos_cd_updated_at before update on public.pedidos_cd
  for each row execute function public.cd_set_updated_at();
drop trigger if exists trg_transferencias_updated_at on public.transferencias;
create trigger trg_transferencias_updated_at before update on public.transferencias
  for each row execute function public.cd_set_updated_at();
drop trigger if exists trg_reservas_updated_at on public.reservas;
create trigger trg_reservas_updated_at before update on public.reservas
  for each row execute function public.cd_set_updated_at();

create index if not exists pedidos_cd_local_status_idx on public.pedidos_cd (tenant_id, local_id, status);
create index if not exists transferencias_pedido_idx on public.transferencias (tenant_id, pedido_cd_id);
create index if not exists reservas_pedido_idx on public.reservas (tenant_id, pedido_cd_id);
create index if not exists reservas_endereco_idx on public.reservas (tenant_id, endereco_id);

-- 6) RLS: leitura por membro ou staff; escrita fechada
alter table public.cd_configuracoes enable row level security;
alter table public.regras_saida enable row level security;
alter table public.pedidos_cd enable row level security;
alter table public.pedidos_cd_itens enable row level security;
alter table public.transferencias enable row level security;
alter table public.transferencia_itens enable row level security;
alter table public.reservas enable row level security;

create policy cd_configuracoes_select_member_or_staff on public.cd_configuracoes for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));
create policy regras_saida_select_member_or_staff on public.regras_saida for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));
create policy pedidos_cd_select_member_or_staff on public.pedidos_cd for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));
create policy pedidos_cd_itens_select_member_or_staff on public.pedidos_cd_itens for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));
create policy transferencias_select_member_or_staff on public.transferencias for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));
create policy transferencia_itens_select_member_or_staff on public.transferencia_itens for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));
create policy reservas_select_member_or_staff on public.reservas for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));

revoke all on public.cd_configuracoes, public.regras_saida, public.pedidos_cd, public.pedidos_cd_itens,
  public.transferencias, public.transferencia_itens, public.reservas from anon;
revoke insert, update, delete on public.cd_configuracoes, public.regras_saida, public.pedidos_cd, public.pedidos_cd_itens,
  public.transferencias, public.transferencia_itens, public.reservas from authenticated;

comment on table public.cd_configuracoes is 'M54-G3. Limites de aprovação automática e política de falta por tenant. Escrita só por RPC (M54-G4).';
comment on table public.regras_saida is 'M54-G3. Ordem de local de saída por canal (web: cd, loja; balcão e shopee: loja).';
comment on table public.pedidos_cd is 'M54-G3. Pedido de saída pelo CD ou loja via canal. Baixa no CD na coleta, na loja no despacho.';
comment on table public.transferencias is 'M54-G3. Transferência automática loja → CD vinculada ao pedido quando há falta.';
comment on table public.reservas is 'M54-G3. Reserva de quantidade por produto e endereço para um pedido. Consumo e liberação por RPC (M54-G4).';
