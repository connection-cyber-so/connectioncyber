-- ConnectionCyber — M05: cadastros e catálogo universal multiempresa.
begin;

create table public.erp_parties (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  kind text not null check (kind in ('person','organization')),
  legal_name text not null check (length(btrim(legal_name)) between 2 and 180),
  trade_name text,
  tax_id text check (tax_id is null or tax_id ~ '^[0-9]{11}$|^[0-9]{14}$'),
  state_registration text,
  municipal_registration text,
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint erp_parties_tenant_id_unique unique (tenant_id,id)
);
create unique index erp_parties_tax_id_unique on public.erp_parties(tenant_id,tax_id) where tax_id is not null and active;
create index erp_parties_search on public.erp_parties(tenant_id,active,legal_name);

create table public.erp_party_roles (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  party_id uuid not null,
  role text not null check (role in ('customer','supplier','employee','buyer','sales_rep','technician','carrier','other')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (tenant_id,party_id,role),
  foreign key (tenant_id,party_id) references public.erp_parties(tenant_id,id) on delete cascade
);

create table public.erp_party_documents (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  party_id uuid not null, type text not null check (type in ('cpf','cnpj','rg','passport','other')),
  number text not null check (length(btrim(number)) between 3 and 40), issuer text, issued_at date, expires_at date,
  created_at timestamptz not null default now(),
  unique (tenant_id,type,number), unique (tenant_id,id),
  foreign key (tenant_id,party_id) references public.erp_parties(tenant_id,id) on delete cascade,
  check (expires_at is null or issued_at is null or expires_at > issued_at)
);

create table public.erp_party_contacts (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  party_id uuid not null, type text not null check (type in ('email','phone','mobile','whatsapp','website','other')),
  value text not null check (length(btrim(value)) between 3 and 254), label text, is_primary boolean not null default false,
  created_at timestamptz not null default now(), unique (tenant_id,id),
  foreign key (tenant_id,party_id) references public.erp_parties(tenant_id,id) on delete cascade
);
create unique index erp_party_contacts_one_primary on public.erp_party_contacts(tenant_id,party_id,type) where is_primary;

create table public.erp_party_addresses (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  party_id uuid not null, type text not null default 'main' check (type in ('main','billing','shipping','service','other')),
  postal_code text, street text not null, number text, complement text, district text, city text not null,
  state_code text check (state_code is null or state_code ~ '^[A-Z]{2}$'), country_code text not null default 'BR' check (country_code ~ '^[A-Z]{2}$'),
  is_primary boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,id), foreign key (tenant_id,party_id) references public.erp_parties(tenant_id,id) on delete cascade
);
create unique index erp_party_addresses_one_primary on public.erp_party_addresses(tenant_id,party_id,type) where is_primary;

create table public.erp_employees (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  party_id uuid not null, establishment_id uuid, employee_code text not null, job_title text, hired_at date, terminated_at date,
  status text not null default 'active' check (status in ('active','leave','terminated')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,employee_code), unique (tenant_id,id), unique (tenant_id,party_id),
  foreign key (tenant_id,party_id) references public.erp_parties(tenant_id,id) on delete restrict,
  foreign key (tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict,
  check (terminated_at is null or hired_at is null or terminated_at >= hired_at)
);

create table public.erp_units (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9]{1,12}$'), name text not null, dimension text not null default 'count' check (dimension in ('count','mass','length','volume','area','time','other')),
  decimal_scale smallint not null default 0 check (decimal_scale between 0 and 6), active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,code), constraint erp_units_tenant_id_unique unique (tenant_id,id)
);

create table public.erp_unit_conversions (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  from_unit_id uuid not null, to_unit_id uuid not null, factor numeric(19,9) not null check (factor > 0),
  created_at timestamptz not null default now(), unique (tenant_id,from_unit_id,to_unit_id), unique (tenant_id,id),
  foreign key (tenant_id,from_unit_id) references public.erp_units(tenant_id,id) on delete cascade,
  foreign key (tenant_id,to_unit_id) references public.erp_units(tenant_id,id) on delete cascade,
  check (from_unit_id <> to_unit_id)
);

create table public.erp_catalog_items (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  kind text not null check (kind in ('product','service','part','ingredient','prepared','kit','supply','fee','voucher')),
  code text not null check (length(btrim(code)) between 1 and 64), name text not null check (length(btrim(name)) between 2 and 180),
  description text, base_unit_id uuid not null, track_inventory boolean not null default false,
  allows_fraction boolean not null default false, status text not null default 'active' check (status in ('draft','active','inactive')),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object'),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,code), constraint erp_catalog_items_tenant_id_unique unique (tenant_id,id),
  foreign key (tenant_id,base_unit_id) references public.erp_units(tenant_id,id) on delete restrict,
  check (kind not in ('service','fee','voucher') or not track_inventory)
);
create index erp_catalog_items_search on public.erp_catalog_items(tenant_id,status,kind,name);

create table public.erp_item_variants (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  item_id uuid not null, code text not null, name text not null, status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,code), unique (tenant_id,id), unique (tenant_id,item_id,id),
  foreign key (tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete cascade
);

create table public.erp_item_identifiers (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  item_id uuid not null, variant_id uuid, type text not null check (type in ('sku','ean8','ean13','gtin','internal','supplier')),
  value text not null check (length(btrim(value)) between 1 and 64), created_at timestamptz not null default now(),
  unique (tenant_id,type,value), unique (tenant_id,id),
  foreign key (tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete cascade,
  foreign key (tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete cascade
);

create table public.erp_attributes (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  code text not null, name text not null, data_type text not null default 'option' check (data_type in ('option','text','number','boolean')),
  active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,code), unique (tenant_id,id)
);
create table public.erp_attribute_values (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  attribute_id uuid not null, code text not null, label text not null, sort_order integer not null default 0,
  active boolean not null default true, created_at timestamptz not null default now(), unique (tenant_id,attribute_id,code), unique (tenant_id,id), unique (tenant_id,attribute_id,id),
  foreign key (tenant_id,attribute_id) references public.erp_attributes(tenant_id,id) on delete cascade
);
create table public.erp_item_attribute_values (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade, item_id uuid not null, variant_id uuid,
  attribute_id uuid not null, attribute_value_id uuid, text_value text, number_value numeric(19,6), boolean_value boolean,
  created_at timestamptz not null default now(), unique nulls not distinct (tenant_id,item_id,attribute_id,variant_id), unique (tenant_id,id),
  foreign key (tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete cascade,
  foreign key (tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete cascade,
  foreign key (tenant_id,attribute_id) references public.erp_attributes(tenant_id,id) on delete cascade,
  foreign key (tenant_id,attribute_id,attribute_value_id) references public.erp_attribute_values(tenant_id,attribute_id,id) on delete restrict,
  check (num_nonnulls(attribute_value_id,text_value,number_value,boolean_value)=1)
);

create table public.erp_item_compositions (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  item_id uuid not null, kind text not null default 'bill_of_materials' check (kind in ('bill_of_materials','recipe','kit')),
  yield_quantity numeric(19,6) not null default 1 check (yield_quantity > 0), yield_unit_id uuid not null,
  version integer not null default 1 check (version > 0), active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique (tenant_id,item_id,version), unique (tenant_id,id),
  foreign key (tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete cascade,
  foreign key (tenant_id,yield_unit_id) references public.erp_units(tenant_id,id) on delete restrict
);
create table public.erp_item_composition_lines (
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
  composition_id uuid not null, component_item_id uuid not null, component_variant_id uuid,
  quantity numeric(19,6) not null check (quantity > 0), unit_id uuid not null, loss_percent numeric(7,4) not null default 0 check (loss_percent between 0 and 100),
  sort_order integer not null default 0, created_at timestamptz not null default now(), unique (tenant_id,id),
  foreign key (tenant_id,composition_id) references public.erp_item_compositions(tenant_id,id) on delete cascade,
  foreign key (tenant_id,component_item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
  foreign key (tenant_id,component_item_id,component_variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
  foreign key (tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict
);

insert into public.erp_permissions(key,name,description,category) values
('parties.read','Consultar cadastros','Consulta pessoas e organizações do tenant.','Cadastros'),
('parties.manage','Gerenciar cadastros','Cria e altera pessoas e organizações do tenant.','Cadastros'),
('catalog.read','Consultar catálogo','Consulta itens, unidades e composições do tenant.','Catálogo'),
('catalog.manage','Gerenciar catálogo','Cria e altera itens, unidades e composições do tenant.','Catálogo')
on conflict (key) do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

-- Cadastro de pessoa + papel precisa ser atômico.
create or replace function public.erp_create_party(
  p_tenant_id uuid, p_kind text, p_legal_name text, p_trade_name text,
  p_tax_id text, p_role text
) returns uuid
language plpgsql security invoker set search_path=''
as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into public.erp_parties(id,tenant_id,kind,legal_name,trade_name,tax_id)
  values(v_id,p_tenant_id,p_kind,btrim(p_legal_name),nullif(btrim(p_trade_name),''),nullif(btrim(p_tax_id),''));
  insert into public.erp_party_roles(tenant_id,party_id,role) values(p_tenant_id,v_id,p_role);
  return v_id;
end $$;

-- updated_at padronizado.
create trigger trg_erp_parties_updated_at before update on public.erp_parties for each row execute function public.set_updated_at();
create trigger trg_erp_party_addresses_updated_at before update on public.erp_party_addresses for each row execute function public.set_updated_at();
create trigger trg_erp_employees_updated_at before update on public.erp_employees for each row execute function public.set_updated_at();
create trigger trg_erp_units_updated_at before update on public.erp_units for each row execute function public.set_updated_at();
create trigger trg_erp_catalog_items_updated_at before update on public.erp_catalog_items for each row execute function public.set_updated_at();
create trigger trg_erp_item_variants_updated_at before update on public.erp_item_variants for each row execute function public.set_updated_at();
create trigger trg_erp_attributes_updated_at before update on public.erp_attributes for each row execute function public.set_updated_at();
create trigger trg_erp_item_compositions_updated_at before update on public.erp_item_compositions for each row execute function public.set_updated_at();

-- RLS: leitura por membership/permissão e escrita apenas manage ou equipe.
do $$ declare t text; domain text; begin
  foreach t in array array['erp_parties','erp_party_roles','erp_party_documents','erp_party_contacts','erp_party_addresses','erp_employees'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''parties.read'')) or (select erp_security.has_permission(tenant_id,''parties.manage'')) or (select public.is_platform_staff()))',t||'_select',t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''parties.manage'')) or (select public.is_platform_staff()))',t||'_insert',t);
    execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''parties.manage'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''parties.manage'')) or (select public.is_platform_staff()))',t||'_update',t);
  end loop;
  foreach t in array array['erp_units','erp_unit_conversions','erp_catalog_items','erp_item_variants','erp_item_identifiers','erp_attributes','erp_attribute_values','erp_item_attribute_values','erp_item_compositions','erp_item_composition_lines'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''catalog.read'')) or (select erp_security.has_permission(tenant_id,''catalog.manage'')) or (select public.is_platform_staff()))',t||'_select',t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''catalog.manage'')) or (select public.is_platform_staff()))',t||'_insert',t);
    execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''catalog.manage'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''catalog.manage'')) or (select public.is_platform_staff()))',t||'_update',t);
  end loop;
end $$;

revoke all on table public.erp_parties,public.erp_party_roles,public.erp_party_documents,public.erp_party_contacts,public.erp_party_addresses,public.erp_employees,public.erp_units,public.erp_unit_conversions,public.erp_catalog_items,public.erp_item_variants,public.erp_item_identifiers,public.erp_attributes,public.erp_attribute_values,public.erp_item_attribute_values,public.erp_item_compositions,public.erp_item_composition_lines from anon,authenticated;
grant select,insert,update on table public.erp_parties,public.erp_party_roles,public.erp_party_documents,public.erp_party_contacts,public.erp_party_addresses,public.erp_employees,public.erp_units,public.erp_unit_conversions,public.erp_catalog_items,public.erp_item_variants,public.erp_item_identifiers,public.erp_attributes,public.erp_attribute_values,public.erp_item_attribute_values,public.erp_item_compositions,public.erp_item_composition_lines to authenticated;
grant all on table public.erp_parties,public.erp_party_roles,public.erp_party_documents,public.erp_party_contacts,public.erp_party_addresses,public.erp_employees,public.erp_units,public.erp_unit_conversions,public.erp_catalog_items,public.erp_item_variants,public.erp_item_identifiers,public.erp_attributes,public.erp_attribute_values,public.erp_item_attribute_values,public.erp_item_compositions,public.erp_item_composition_lines to service_role;

revoke execute on function public.erp_create_party(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.erp_create_party(uuid,text,text,text,text,text) to authenticated,service_role;

commit;
