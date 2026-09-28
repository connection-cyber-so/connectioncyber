-- =============================================================================
-- ConnectionCyber — M03: resolução segura de domínio do portal
--
-- ESCOPO ADITIVO:
--   - domínios canônicos por tenant;
--   - normalização estrita de hostname;
--   - resolver público mínimo, sem SELECT anônimo na tabela;
--   - leitura de tenants por membership ERP ativa.
--
-- FORA DE ESCOPO:
--   provisionamento de usuários, convites, RBAC/MFA, dados reais, DNS, Vercel,
--   produção, certificado A1, fiscal, Mercado Pago e migração de legado.
--
-- IMPORTANTE: este arquivo deve ser revisado e testado antes de qualquer db push.
-- =============================================================================

begin;

create or replace function erp_security.normalize_hostname(p_hostname text)
returns text
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
declare
  normalized text := lower(btrim(p_hostname));
  label text;
begin
  normalized := regexp_replace(normalized, '\.$', '');

  if length(normalized) not between 4 and 253
     or normalized !~ '^[a-z0-9.-]+$'
     or array_length(string_to_array(normalized, '.'), 1) < 2 then
    return null;
  end if;

  foreach label in array string_to_array(normalized, '.') loop
    if length(label) not between 1 and 63
       or label !~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$' then
      return null;
    end if;
  end loop;

  return normalized;
end
$$;

revoke all on function erp_security.normalize_hostname(text) from public, anon, authenticated;
grant execute on function erp_security.normalize_hostname(text) to service_role;

create table public.erp_tenant_domains (
  id                  uuid primary key default gen_random_uuid(),
  tenant_id           uuid not null references public.tenants(id) on delete cascade,
  hostname            text not null,
  domain_type         text not null default 'subdomain'
                      check (domain_type in ('subdomain', 'custom')),
  status              text not null default 'pending'
                      check (status in ('pending', 'active', 'suspended', 'revoked')),
  is_primary          boolean not null default false,
  verification_method text check (
                        verification_method is null
                        or verification_method in ('dns_txt', 'dns_cname', 'platform')
                      ),
  verified_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint erp_tenant_domains_hostname_canonical
    check (hostname = erp_security.normalize_hostname(hostname)),
  constraint erp_tenant_domains_reserved_connectioncyber_hosts
    check (hostname not in (
      'connectioncyber.com.br',
      'www.connectioncyber.com.br',
      'portal.connectioncyber.com.br',
      'admin.connectioncyber.com.br',
      'api.connectioncyber.com.br'
    )),
  constraint erp_tenant_domains_subdomain_scope
    check (
      domain_type <> 'subdomain'
      or hostname ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.connectioncyber\.com\.br$'
    ),
  constraint erp_tenant_domains_active_verified
    check (status <> 'active' or verified_at is not null),
  constraint erp_tenant_domains_primary_active
    check (not is_primary or status = 'active'),
  constraint erp_tenant_domains_hostname_unique unique (hostname),
  constraint erp_tenant_domains_tenant_id_unique unique (tenant_id, id)
);

create index erp_tenant_domains_tenant_status
  on public.erp_tenant_domains(tenant_id, status);
create index erp_tenant_domains_active_lookup
  on public.erp_tenant_domains(hostname, tenant_id)
  where status = 'active' and verified_at is not null;
create unique index erp_tenant_domains_one_primary_active
  on public.erp_tenant_domains(tenant_id)
  where is_primary and status = 'active';

create trigger trg_erp_tenant_domains_updated_at
  before update on public.erp_tenant_domains
  for each row execute function public.set_updated_at();

create or replace function public.portal_resolve_host(p_hostname text)
returns table (
  domain_id uuid,
  tenant_id uuid,
  tenant_slug text,
  tenant_name text,
  hostname text,
  domain_type text
)
language sql
stable
security definer
set search_path = ''
rows 1
as $$
  select
    domain.id,
    domain.tenant_id,
    tenant.slug,
    tenant.nome,
    domain.hostname,
    domain.domain_type
  from public.erp_tenant_domains domain
  join public.tenants tenant on tenant.id = domain.tenant_id
  where domain.hostname = erp_security.normalize_hostname(p_hostname)
    and domain.status = 'active'
    and domain.verified_at is not null
    and tenant.ativo
  limit 1
$$;

revoke all on function public.portal_resolve_host(text) from public;
grant execute on function public.portal_resolve_host(text) to anon, authenticated, service_role;

alter table public.erp_tenant_domains enable row level security;

create policy erp_tenant_domains_select_own_membership
  on public.erp_tenant_domains for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)));

create policy tenants_select_erp_membership
  on public.tenants for select to authenticated
  using ((select erp_security.is_tenant_member(id)));

revoke all on table public.erp_tenant_domains from public, anon, authenticated;
grant select on table public.erp_tenant_domains to authenticated;
grant all on table public.erp_tenant_domains to service_role;

comment on table public.erp_tenant_domains is
  'Hostnames canônicos do portal. O hostname identifica contexto, mas não concede acesso.';
comment on function public.portal_resolve_host(text) is
  'Resolve um hostname exato e ativo para identidade pública mínima; não autoriza acesso ao tenant.';
comment on function erp_security.normalize_hostname(text) is
  'Normalização privada e estrita de FQDN ASCII, sem porta, caminho ou wildcard.';
comment on policy tenants_select_erp_membership on public.tenants is
  'Permite ao usuário multiempresa ler tenants de memberships ERP ativas, sem bypass automático de staff.';

commit;
