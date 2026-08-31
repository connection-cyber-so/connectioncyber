-- ConnectionCyber - M16: capacidades, entitlements e excecoes tenant-scoped.
begin;

create table public.erp_capability_catalog(
 key text primary key check(key~'^[a-z][a-z0-9_]{2,63}$'),
 name text not null check(length(btrim(name))between 3 and 80),
 description text not null check(length(btrim(description))between 3 and 240),
 risk_level text not null check(risk_level in('standard','controlled','critical')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);

create table public.erp_tenant_capability_entitlements(
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id)on delete cascade,
 capability_key text not null references public.erp_capability_catalog(key)on delete restrict,
 enabled boolean not null default false,
 source text not null check(source in('blueprint','contract','migration')),
 contract_version integer not null check(contract_version>0),
 effective_from timestamptz not null,
 effective_until timestamptz,
 evidence_hash text not null check(evidence_hash~'^[a-f0-9]{64}$'),
 created_at timestamptz not null default now(),
 unique(tenant_id,capability_key,contract_version),
 unique(tenant_id,id),
 check(effective_until is null or effective_until>effective_from)
);

create table public.erp_tenant_capability_exceptions(
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id)on delete cascade,
 capability_key text not null references public.erp_capability_catalog(key)on delete restrict,
 effect text not null check(effect in('allow','deny')),
 reason_hash text not null check(reason_hash~'^[a-f0-9]{64}$'),
 approval_ref text not null check(approval_ref~'^approval:sha256:[a-f0-9]{64}$'),
 effective_from timestamptz not null,
 expires_at timestamptz not null,
 status text not null default'active'check(status in('active','revoked','expired')),
 created_at timestamptz not null default now(),
 revoked_at timestamptz,
 unique(tenant_id,id),
 unique(tenant_id,capability_key,approval_ref),
 check(expires_at>effective_from),
 check((status='revoked'and revoked_at is not null)or(status<>'revoked'and revoked_at is null))
);

insert into public.erp_capability_catalog(key,name,description,risk_level)values
('parties','Cadastros','Clientes, fornecedores e pessoas do tenant.','standard'),
('catalog','Catalogo','Produtos e servicos do tenant.','standard'),
('sales','Vendas','Orcamentos, pedidos e vendas.','standard'),
('cash','Caixa','Abertura, movimentos e fechamento.','controlled'),
('finance','Financeiro','Contas a pagar, receber e conciliacao.','controlled'),
('inventory','Estoque','Saldos e movimentos de estoque.','standard'),
('services','Servicos','Agenda, ativos e ordens de servico.','standard'),
('restaurant','Restaurante','Mesas, comandas e cozinha.','controlled'),
('remote_support','Suporte remoto','Atendimento remoto sob consentimento.','critical'),
('device_agent','Agente local','Integracao protegida com perifericos.','critical'),
('fiscal','Fiscal','Documentos e operacoes fiscais.','critical'),
('legacy_import','Importacao','Importacao controlada de legado.','critical')
on conflict(key)do update set name=excluded.name,description=excluded.description,risk_level=excluded.risk_level,active=true;

insert into public.erp_permissions(key,name,description,category)values
('capabilities.read','Consultar capacidades','Consulta capacidades efetivas do tenant.','Plataforma'),
('capabilities.manage','Gerenciar capacidades','Administra contratos e excecoes de capacidades.','Plataforma')
on conflict(key)do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

create index idx_capability_entitlements_tenant_active on public.erp_tenant_capability_entitlements(tenant_id,capability_key,effective_from,effective_until);
create index idx_capability_exceptions_tenant_active on public.erp_tenant_capability_exceptions(tenant_id,capability_key,status,effective_from,expires_at);

alter table public.erp_capability_catalog enable row level security;
alter table public.erp_tenant_capability_entitlements enable row level security;
alter table public.erp_tenant_capability_exceptions enable row level security;
revoke all on public.erp_capability_catalog,public.erp_tenant_capability_entitlements,public.erp_tenant_capability_exceptions from anon,authenticated;
grant select on public.erp_capability_catalog,public.erp_tenant_capability_entitlements,public.erp_tenant_capability_exceptions to authenticated;
revoke all on public.erp_capability_catalog,public.erp_tenant_capability_entitlements,public.erp_tenant_capability_exceptions from service_role;
grant select on public.erp_capability_catalog,public.erp_tenant_capability_entitlements,public.erp_tenant_capability_exceptions to service_role;
grant insert on public.erp_tenant_capability_entitlements,public.erp_tenant_capability_exceptions to service_role;

create policy erp_capability_catalog_select on public.erp_capability_catalog for select to authenticated using(active);
create policy erp_tenant_capability_entitlements_select on public.erp_tenant_capability_entitlements for select to authenticated using(erp_security.has_permission(tenant_id,'capabilities.read')or erp_security.has_permission(tenant_id,'capabilities.manage')or public.is_platform_staff());
create policy erp_tenant_capability_exceptions_select on public.erp_tenant_capability_exceptions for select to authenticated using(erp_security.has_permission(tenant_id,'capabilities.read')or erp_security.has_permission(tenant_id,'capabilities.manage')or public.is_platform_staff());

create or replace function public.erp_resolve_tenant_capabilities(p_tenant_id uuid,p_at timestamptz default now())
returns table(capability_key text,status text,source text)
language plpgsql stable security invoker set search_path='' as $$
begin
 if not(auth.role()='service_role'or erp_security.has_permission(p_tenant_id,'capabilities.read')or erp_security.has_permission(p_tenant_id,'capabilities.manage')or public.is_platform_staff())then raise exception 'capability access denied';end if;
 return query
 with entitlement as(
  select distinct on(e.capability_key)e.capability_key,e.enabled,e.source
  from public.erp_tenant_capability_entitlements e
  where e.tenant_id=p_tenant_id and e.effective_from<=p_at and(e.effective_until is null or e.effective_until>p_at)
  order by e.capability_key,e.contract_version desc,e.created_at desc
 ),exception_state as(
  select x.capability_key,bool_or(x.effect='deny')as denied,bool_or(x.effect='allow')as allowed
  from public.erp_tenant_capability_exceptions x
  where x.tenant_id=p_tenant_id and x.status='active'and x.effective_from<=p_at and x.expires_at>p_at
  group by x.capability_key
 )
 select c.key,
  case when coalesce(x.denied,false)then'disabled'when coalesce(x.allowed,false)then'enabled'when coalesce(e.enabled,false)then'enabled'else'disabled'end,
  case when coalesce(x.denied,false)then'exception_deny'when coalesce(x.allowed,false)then'exception_allow'when e.capability_key is not null then e.source else'default_deny'end
 from public.erp_capability_catalog c left join entitlement e on e.capability_key=c.key left join exception_state x on x.capability_key=c.key
 where c.active order by c.key;
end$$;

create or replace function public.erp_revoke_capability_exception(p_tenant_id uuid,p_exception_id uuid,p_revoked_at timestamptz default now())
returns boolean language plpgsql security definer set search_path=''as $$
declare v_status text;
begin
 if auth.role()<>'service_role'then raise exception 'broker only';end if;
 if p_tenant_id is null or p_exception_id is null or p_revoked_at is null or p_revoked_at>now()+interval'5 minutes'then raise exception 'invalid revocation';end if;
 select status into v_status from public.erp_tenant_capability_exceptions where tenant_id=p_tenant_id and id=p_exception_id for update;
 if v_status is null then raise exception 'exception not found';end if;
 if v_status='revoked'then return false;end if;
 if v_status<>'active'then raise exception 'only active exception can be revoked';end if;
 update public.erp_tenant_capability_exceptions set status='revoked',revoked_at=p_revoked_at where tenant_id=p_tenant_id and id=p_exception_id;
 return true;
end$$;
revoke execute on function public.erp_resolve_tenant_capabilities(uuid,timestamptz)from public,anon;
grant execute on function public.erp_resolve_tenant_capabilities(uuid,timestamptz)to authenticated,service_role;
revoke execute on function public.erp_revoke_capability_exception(uuid,uuid,timestamptz)from public,anon,authenticated,service_role;
grant execute on function public.erp_revoke_capability_exception(uuid,uuid,timestamptz)to service_role;

commit;
