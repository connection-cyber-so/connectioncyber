-- 0056_cd_planos_capacidades.sql
-- Data: 2026-11-06
-- Origem: M54-G2. Capacidades do Centro Logístico (CD) e do canal web da loja, com dependências.
-- Decisões (aprovadas em 06/11/2026): plano como capacidade; canal web usa 'site.loja';
--   CD precisa de armazenagem antes de expedição; ambas dependem de estoque.
-- Escopo: catálogo (3 chaves), tabela de dependências (somente leitura para clientes),
--   trigger fail-closed que impede ativar capacidade sem a dependência ativa no mesmo tenant.
--   Concede as 3 capacidades ao tenant Nuvem de Papel como 'active' (plano da Nuvem), com evidence_hash SHA-256 do contrato M54-G2.
-- Fora de escopo: transferências, pedidos_cd, regras_saida (M54-G3); dados FICTICIO (M54-G4).
-- Reversão: supabase/rollback/0056_cd_planos_capacidades.rollback.sql (só sem vínculo ativo).

insert into public.erp_capability_catalog (key, name, description, category, risk_level) values
  ('cd.armazenagem', 'Armazenagem do CD', 'Cadastro de locais, endereços e saldos do Centro Logístico (galpão e salão).', 'inventory', 'standard'),
  ('cd.expedicao', 'Expedição do CD', 'Coleta, separação e baixa de pedidos no Centro Logístico.', 'inventory', 'controlled'),
  ('site.loja', 'Canal web da loja', 'Venda pelo site ligada ao estoque da loja e do CD.', 'sales', 'controlled')
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  risk_level = excluded.risk_level,
  active = true;

create table if not exists public.erp_capability_dependencies (
  capability_key text not null references public.erp_capability_catalog(key) on delete restrict,
  requires_key   text not null references public.erp_capability_catalog(key) on delete restrict,
  created_at     timestamptz not null default now(),
  primary key (capability_key, requires_key),
  constraint erp_capability_dependencies_no_self check (capability_key <> requires_key)
);

alter table public.erp_capability_dependencies enable row level security;

create policy erp_capability_dependencies_select_authenticated
  on public.erp_capability_dependencies for select to authenticated
  using (true);

revoke all on public.erp_capability_dependencies from anon;
revoke insert, update, delete on public.erp_capability_dependencies from authenticated;

insert into public.erp_capability_dependencies (capability_key, requires_key) values
  ('cd.armazenagem', 'inventory.stock'),
  ('cd.expedicao', 'cd.armazenagem'),
  ('site.loja', 'sales.pos'),
  ('site.loja', 'inventory.stock')
on conflict do nothing;

-- Fail-closed: não ativa (nem deixa em trial) capacidade cuja dependência não esteja ativa ou em trial no mesmo tenant.
create or replace function public.erp_enforce_capability_dependencies()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text;
begin
  if new.status not in ('trial', 'active') then
    return new;
  end if;

  select d.requires_key into v_missing
  from public.erp_capability_dependencies d
  where d.capability_key = new.capability_key
    and not exists (
      select 1 from public.erp_tenant_capabilities t
      where t.tenant_id = new.tenant_id
        and t.capability_key = d.requires_key
        and t.status in ('trial', 'active')
    )
  limit 1;

  if v_missing is not null then
    raise exception 'capacidade % exige % ativa no tenant', new.capability_key, v_missing
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_erp_tenant_capabilities_deps on public.erp_tenant_capabilities;
create trigger trg_erp_tenant_capabilities_deps
  before insert or update of status, capability_key on public.erp_tenant_capabilities
  for each row execute function public.erp_enforce_capability_dependencies();

-- Concessão ao tenant Nuvem de Papel. Ordem obrigatória: estoque e PDV já ativos (0054), depois armazenagem, expedição e canal web.
insert into public.erp_tenant_capabilities (tenant_id, capability_key, status, source, contract_version, evidence_hash)
values ('00000000-0000-0000-0000-000000000001'::uuid, 'cd.armazenagem', 'active', 'migration', 1,
  encode(sha256(convert_to('M54-G2|cd.armazenagem|00000000-0000-0000-0000-000000000001', 'UTF8')), 'hex'));
insert into public.erp_tenant_capabilities (tenant_id, capability_key, status, source, contract_version, evidence_hash)
values ('00000000-0000-0000-0000-000000000001'::uuid, 'cd.expedicao', 'active', 'migration', 1,
  encode(sha256(convert_to('M54-G2|cd.expedicao|00000000-0000-0000-0000-000000000001', 'UTF8')), 'hex'));
insert into public.erp_tenant_capabilities (tenant_id, capability_key, status, source, contract_version, evidence_hash)
values ('00000000-0000-0000-0000-000000000001'::uuid, 'site.loja', 'active', 'migration', 1,
  encode(sha256(convert_to('M54-G2|site.loja|00000000-0000-0000-0000-000000000001', 'UTF8')), 'hex'));

comment on table public.erp_capability_dependencies is 'M54-G2. Dependências entre capacidades. Escrita só por migration.';
comment on function public.erp_enforce_capability_dependencies() is 'M54-G2. Fail-closed: capacidade ativa/trial exige dependências ativas/trial no mesmo tenant.';
