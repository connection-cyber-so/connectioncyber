-- 0053_tenant_domains.sql
-- Data: 2026-11-05
-- Origem: integração da Nuvem de Papel ao banco multi-tenant (decisão aprovada pelo responsável em 05/11/2026).
-- Escopo: tabela public.tenant_domains (hostname -> tenant) com status de verificação, RLS
--   ligada sem policies (só service_role acessa) e função public.resolve_tenant_by_host.
-- Fora de escopo: cadastro do tenant da Nuvem de Papel (migration de dados posterior, só inserts).
-- Pendências: public.tenants.dominio é mantido por compatibilidade; deprecar depois.
-- Reversão: supabase/rollback/0053_tenant_domains.rollback.sql (só com tabela vazia).

create table if not exists public.tenant_domains (
  hostname       text primary key,
  tenant_id      uuid not null references public.tenants(id) on delete restrict,
  status         text not null default 'pendente',
  verificado_em  timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint tenant_domains_hostname_ck check (
    hostname = lower(hostname)
    and length(hostname) between 4 and 253
    and hostname ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
  ),
  constraint tenant_domains_status_ck check (status in ('pendente', 'verificado', 'ativo', 'suspenso')),
  constraint tenant_domains_verificado_ck check (
    status = 'pendente' or verificado_em is not null
  )
);

comment on table public.tenant_domains is
  'Domínios próprios de cada tenant. Só status verificado ou ativo resolve tenant. Escrita só por service_role.';

create index if not exists tenant_domains_tenant_idx on public.tenant_domains (tenant_id);

alter table public.tenant_domains enable row level security;
revoke all on public.tenant_domains from anon, authenticated;

create or replace function public.resolve_tenant_by_host(p_host text)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select td.tenant_id
    from public.tenant_domains td
    join public.tenants t on t.id = td.tenant_id
   where td.hostname = lower(p_host)
     and td.status in ('verificado', 'ativo')
     and t.ativo
   limit 1
$$;

revoke all on function public.resolve_tenant_by_host(text) from public, anon, authenticated;
grant execute on function public.resolve_tenant_by_host(text) to service_role;
