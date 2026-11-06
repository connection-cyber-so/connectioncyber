-- 0055_cd_locais_enderecos_saldos.sql
-- Data: 2026-11-06
-- Origem: M54-G1. Estrutura de locais, endereços e saldos do Centro Logístico.
-- Escopo: public.locais (loja | cd), public.enderecos (zona galpão/salão, rua, box,
--   tipo de uso), public.saldos (qtd e reservado por endereço), RLS por membership
--   (leitura) e nenhuma policy de escrita: escrita só por RPC security definer em gate posterior.
-- Decisões (aprovadas em 06/11/2026): loja = 1 endereço de venda; CD = galpão + salão;
--   saldo controlado por endereço; disponível = Σ(qtd − reservado) do tenant.
-- Fora de escopo: catálogo de produtos (não existe no repositório ainda; saldos.produto_id
--   fica SEM FK até o gate do catálogo — pendência explícita), transferências, pedidos_cd,
--   planos e capacidades (M54-G2/G3), dados fictícios (migration de seed separada, marcada FICTICIO).
-- Reversão: supabase/rollback/0055_cd_locais_enderecos_saldos.rollback.sql (só com tabelas vazias).

-- 1) Locais: uma loja física ou o Centro Logístico de um tenant
create table if not exists public.locais (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants(id) on delete restrict,
  codigo        text not null check (codigo ~ '^[A-Z0-9][A-Z0-9_-]{0,31}$'),
  tipo          text not null check (tipo in ('loja', 'cd')),
  nome          text not null check (length(trim(nome)) > 0),
  ativo         boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint locais_tenant_codigo_unique unique (tenant_id, codigo),
  constraint locais_tenant_id_unique unique (tenant_id, id)
);

-- 2) Endereços: cada box/posição do CD e o único endereço da loja
create table if not exists public.enderecos (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references public.tenants(id) on delete restrict,
  local_id            uuid not null,
  zona                text check (zona in ('galpao', 'salao')),
  rua                 text,
  box                 text,
  tipo_uso            text not null check (tipo_uso in ('armazenagem', 'separacao', 'recebimento', 'expedicao', 'venda')),
  capacidade_posicoes integer check (capacidade_posicoes is null or capacidade_posicoes > 0),
  ativo               boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint enderecos_local_fk foreign key (tenant_id, local_id)
    references public.locais(tenant_id, id) on delete restrict,
  constraint enderecos_tenant_id_unique unique (tenant_id, id),
  constraint enderecos_local_rua_box_unique unique (local_id, rua, box),
  -- loja: exatamente um endereço de venda, sem zona/rua/box; CD: sempre com zona, rua e box
  constraint enderecos_uso_por_tipo check (
    (tipo_uso = 'venda' and zona is null and rua is null and box is null)
    or (tipo_uso <> 'venda' and zona is not null and rua is not null and box is not null)
  )
);

-- Garante que só existe endereço de venda em local do tipo loja, e endereço de CD em local do tipo cd.
create or replace function public.enderecos_valida_tipo_local()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_tipo_local text;
begin
  select l.tipo into v_tipo_local
  from public.locais l
  where l.tenant_id = new.tenant_id and l.id = new.local_id;

  if v_tipo_local is null then
    raise exception 'local % não existe no tenant', new.local_id;
  end if;

  if new.tipo_uso = 'venda' and v_tipo_local <> 'loja' then
    raise exception 'endereço de venda só pode existir em local do tipo loja';
  end if;

  if new.tipo_uso <> 'venda' and v_tipo_local <> 'cd' then
    raise exception 'endereço de armazenagem/separação/recebimento/expedição só pode existir em local do tipo cd';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enderecos_valida_tipo_local on public.enderecos;
create trigger trg_enderecos_valida_tipo_local
  before insert or update on public.enderecos
  for each row execute function public.enderecos_valida_tipo_local();

-- 3) Saldos: quantidade e reserva por produto × endereço
create table if not exists public.saldos (
  tenant_id    uuid not null references public.tenants(id) on delete restrict,
  produto_id   uuid not null,  -- SEM FK: catálogo de produtos pendente (ver cabeçalho)
  endereco_id  uuid not null,
  qtd          integer not null default 0 check (qtd >= 0),
  reservado    integer not null default 0 check (reservado >= 0),
  updated_at   timestamptz not null default now(),
  primary key (tenant_id, produto_id, endereco_id),
  constraint saldos_endereco_fk foreign key (tenant_id, endereco_id)
    references public.enderecos(tenant_id, id) on delete restrict,
  constraint saldos_reservado_limite check (reservado <= qtd)
);

create index if not exists saldos_endereco_idx on public.saldos (tenant_id, endereco_id);
create index if not exists enderecos_local_idx on public.enderecos (tenant_id, local_id);

-- updated_at automático
create or replace function public.cd_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_locais_updated_at on public.locais;
create trigger trg_locais_updated_at before update on public.locais
  for each row execute function public.cd_set_updated_at();
drop trigger if exists trg_enderecos_updated_at on public.enderecos;
create trigger trg_enderecos_updated_at before update on public.enderecos
  for each row execute function public.cd_set_updated_at();
drop trigger if exists trg_saldos_updated_at on public.saldos;
create trigger trg_saldos_updated_at before update on public.saldos
  for each row execute function public.cd_set_updated_at();

-- 4) RLS: leitura por membro do tenant ou staff; escrita fechada (sem policy de insert/update/delete)
alter table public.locais   enable row level security;
alter table public.enderecos enable row level security;
alter table public.saldos    enable row level security;

create policy locais_select_member_or_staff
  on public.locais for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));

create policy enderecos_select_member_or_staff
  on public.enderecos for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));

create policy saldos_select_member_or_staff
  on public.saldos for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));

revoke all on public.locais, public.enderecos, public.saldos from anon;
revoke insert, update, delete on public.locais, public.enderecos, public.saldos from authenticated;

comment on table public.locais is 'M54-G1. Loja ou Centro Logístico de um tenant. Escrita só por RPC (gate posterior).';
comment on table public.enderecos is 'M54-G1. Endereço de saldo: loja (tipo_uso venda) ou box do CD (zona galpão/salão).';
comment on table public.saldos is 'M54-G1. Saldo por produto e endereço. Disponível = Σ(qtd − reservado) do tenant. produto_id sem FK até o catálogo.';
