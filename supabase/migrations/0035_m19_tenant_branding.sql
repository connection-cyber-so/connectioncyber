-- ConnectionCyber - M19-G3: identidade visual propria por tenant (cor primaria e logo)
-- no portal, sobrepondo a paleta global apenas la. Escrita: cada tenant so mexe na
-- propria linha (RLS insert/update por has_permission), mesmo padrao de erp_create_party
-- (0021) - RPC security invoker, RLS na tabela e' a fronteira de verdade, nao a funcao.
begin;

create table public.erp_tenant_branding (
  tenant_id     uuid primary key references public.tenants(id) on delete cascade,
  primary_color text check (primary_color is null or primary_color ~ '^#[0-9a-f]{6}$'),
  logo_url      text check (logo_url is null or (char_length(logo_url) <= 2048 and logo_url ~ '^https://')),
  updated_at    timestamptz not null default now(),
  updated_by    uuid references auth.users(id) on delete set null
);

create trigger trg_erp_tenant_branding_updated_at
  before update on public.erp_tenant_branding
  for each row execute function public.set_updated_at();

alter table public.erp_tenant_branding enable row level security;
revoke all on public.erp_tenant_branding from anon, authenticated, service_role;
grant select, insert, update on public.erp_tenant_branding to authenticated;
grant all on public.erp_tenant_branding to service_role;

create policy erp_tenant_branding_select on public.erp_tenant_branding
  for select to authenticated
  using ((select erp_security.is_tenant_member(tenant_id)) or (select public.is_platform_staff()));

create policy erp_tenant_branding_insert on public.erp_tenant_branding
  for insert to authenticated
  with check ((select erp_security.has_permission(tenant_id, 'branding.manage')) or (select public.is_platform_staff()));

create policy erp_tenant_branding_update on public.erp_tenant_branding
  for update to authenticated
  using ((select erp_security.has_permission(tenant_id, 'branding.manage')) or (select public.is_platform_staff()))
  with check ((select erp_security.has_permission(tenant_id, 'branding.manage')) or (select public.is_platform_staff()));

insert into public.erp_permissions (key, name, description, category)
values ('branding.manage', 'Gerenciar identidade visual', 'Define cor primaria e logo do portal do proprio tenant.', 'foundation')
on conflict (key) do nothing;

-- Backfill: tenants ja provisionados (ConnectionCyber, Mania de Modas/M18-G21) tiveram
-- seus papeis populados antes desta permissao existir no catalogo - sem isto, owners e
-- admins ja existentes ficariam sem acesso a uma tela que a UI vai mostrar pra eles.
-- Provisionamento futuro (0034 erp_finalize_pilot_identity_v1) ja concede toda permissao
-- ativa ao papel 'owner' automaticamente, entao esse caminho nao precisa de backfill.
insert into public.erp_role_permissions (tenant_id, role_id, permission_id)
select r.tenant_id, r.id, p.id
from public.erp_roles r
join public.erp_permissions p on p.key = 'branding.manage'
where r.key in ('owner', 'admin') and r.active
on conflict do nothing;

create or replace function public.erp_set_tenant_branding(
  p_tenant_id uuid, p_primary_color text, p_logo_url text
) returns void
language plpgsql security invoker set search_path = ''
as $$
declare v_color text := nullif(btrim(p_primary_color), '');
declare v_logo text := nullif(btrim(p_logo_url), '');
begin
  if v_color is not null then
    v_color := lower(v_color);
    if v_color !~ '^#[0-9a-f]{6}$' then raise exception 'invalid primary_color'; end if;
  end if;
  if v_logo is not null and (char_length(v_logo) > 2048 or v_logo !~ '^https://') then
    raise exception 'invalid logo_url';
  end if;
  insert into public.erp_tenant_branding (tenant_id, primary_color, logo_url, updated_by)
  values (p_tenant_id, v_color, v_logo, auth.uid())
  on conflict (tenant_id) do update
    set primary_color = excluded.primary_color, logo_url = excluded.logo_url, updated_by = excluded.updated_by;
end $$;

revoke execute on function public.erp_set_tenant_branding(uuid, text, text) from public, anon;
grant execute on function public.erp_set_tenant_branding(uuid, text, text) to authenticated, service_role;

comment on table public.erp_tenant_branding is
  'Identidade visual opcional por tenant (cor primaria, logo) exibida so no portal daquele tenant; ausente = paleta global padrao.';

commit;
