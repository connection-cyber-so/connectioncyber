-- ConnectionCyber — M06: preços, estoque, inventário e compras.
begin;

create table public.erp_price_lists (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 code text not null, name text not null, currency_code text not null default 'BRL' check(currency_code~'^[A-Z]{3}$'),
 channel text not null default 'general' check(channel in('general','retail','wholesale','online','service')),
 valid_from timestamptz, valid_until timestamptz, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tenant_id,code), unique(tenant_id,id), check(valid_until is null or valid_from is null or valid_until>valid_from)
);
create table public.erp_price_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 price_list_id uuid not null, item_id uuid not null, variant_id uuid, unit_id uuid not null,
 min_quantity numeric(19,6) not null default 1 check(min_quantity>0), price numeric(19,4) not null check(price>=0),
 valid_from timestamptz, valid_until timestamptz, created_at timestamptz not null default now(), unique(tenant_id,id),
 unique nulls not distinct(tenant_id,price_list_id,item_id,variant_id,unit_id,min_quantity,valid_from),
 foreign key(tenant_id,price_list_id) references public.erp_price_lists(tenant_id,id) on delete cascade,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict,
 check(valid_until is null or valid_from is null or valid_until>valid_from)
);
create table public.erp_promotions (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 code text not null, name text not null, kind text not null check(kind in('percent','fixed_price','amount_off')),
 value numeric(19,4) not null check(value>=0), starts_at timestamptz not null, ends_at timestamptz not null,
 active boolean not null default true, conditions jsonb not null default '{}'::jsonb check(jsonb_typeof(conditions)='object'),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,id), check(ends_at>starts_at)
);

create table public.erp_stock_locations (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, code text not null, name text not null,
 kind text not null default 'warehouse' check(kind in('warehouse','store','workshop','kitchen','transit','loss','quarantine')),
 allows_negative boolean not null default false, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,id),
 foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict
);
create table public.erp_stock_lots (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 item_id uuid not null, code text not null, manufactured_at date, expires_at date, active boolean not null default true,
 created_at timestamptz not null default now(), unique(tenant_id,item_id,code), unique(tenant_id,id), unique(tenant_id,item_id,id),
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 check(expires_at is null or manufactured_at is null or expires_at>=manufactured_at)
);
create table public.erp_stock_serials (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 item_id uuid not null, variant_id uuid, serial_number text not null, status text not null default 'available' check(status in('available','reserved','sold','consumed','lost','maintenance')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,serial_number), unique(tenant_id,id), unique(tenant_id,item_id,id),
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict
);
create table public.erp_stock_movements (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, type text not null check(type in('opening','purchase_receipt','sale','return','transfer','inventory_adjustment','production','consumption','reversal')),
 status text not null default 'draft' check(status in('draft','posted','reversed')), occurred_at timestamptz not null default now(), posted_at timestamptz,
 source_type text, source_id uuid, reversal_of_id uuid, idempotency_key text not null, notes text, created_by uuid references auth.users(id),
 created_at timestamptz not null default now(), unique(tenant_id,idempotency_key), unique(tenant_id,id),
 foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict,
 foreign key(tenant_id,reversal_of_id) references public.erp_stock_movements(tenant_id,id) on delete restrict,
 check((status='draft' and posted_at is null) or (status in('posted','reversed') and posted_at is not null))
);
create table public.erp_stock_movement_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 movement_id uuid not null, location_id uuid not null, item_id uuid not null, variant_id uuid, lot_id uuid, serial_id uuid,
 unit_id uuid not null, quantity_delta numeric(19,6) not null check(quantity_delta<>0), unit_cost numeric(19,4) check(unit_cost is null or unit_cost>=0),
 created_at timestamptz not null default now(), unique(tenant_id,id),
 foreign key(tenant_id,movement_id) references public.erp_stock_movements(tenant_id,id) on delete cascade,
 foreign key(tenant_id,location_id) references public.erp_stock_locations(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,item_id,lot_id) references public.erp_stock_lots(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,item_id,serial_id) references public.erp_stock_serials(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict,
 check(serial_id is null or abs(quantity_delta)=1)
);
create table public.erp_stock_reservations (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 location_id uuid not null, item_id uuid not null, variant_id uuid, lot_id uuid, quantity numeric(19,6) not null check(quantity>0),
 status text not null default 'active' check(status in('active','released','fulfilled','expired')), source_type text not null, source_id uuid not null,
 expires_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,id),
 foreign key(tenant_id,location_id) references public.erp_stock_locations(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,item_id,lot_id) references public.erp_stock_lots(tenant_id,item_id,id) on delete restrict
);

create table public.erp_inventory_counts (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 location_id uuid not null, code text not null, status text not null default 'draft' check(status in('draft','counting','review','posted','cancelled')),
 started_at timestamptz, completed_at timestamptz, posted_movement_id uuid, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tenant_id,code), unique(tenant_id,id), foreign key(tenant_id,location_id) references public.erp_stock_locations(tenant_id,id) on delete restrict,
 foreign key(tenant_id,posted_movement_id) references public.erp_stock_movements(tenant_id,id) on delete restrict
);
create table public.erp_inventory_count_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 inventory_count_id uuid not null, item_id uuid not null, variant_id uuid, lot_id uuid, system_quantity numeric(19,6) not null,
 counted_quantity numeric(19,6), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,id),
 unique nulls not distinct(tenant_id,inventory_count_id,item_id,variant_id,lot_id),
 foreign key(tenant_id,inventory_count_id) references public.erp_inventory_counts(tenant_id,id) on delete cascade,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,item_id,lot_id) references public.erp_stock_lots(tenant_id,item_id,id) on delete restrict
);

create table public.erp_purchase_orders (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, supplier_id uuid not null, code text not null,
 status text not null default 'draft' check(status in('draft','approved','partially_received','received','cancelled')),
 currency_code text not null default 'BRL' check(currency_code~'^[A-Z]{3}$'), ordered_at timestamptz, expected_at timestamptz,
 subtotal numeric(19,4) not null default 0, discount_total numeric(19,4) not null default 0, freight_total numeric(19,4) not null default 0, grand_total numeric(19,4) not null default 0,
 notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,id),
 foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict,
 foreign key(tenant_id,supplier_id) references public.erp_parties(tenant_id,id) on delete restrict,
 check(subtotal>=0 and discount_total>=0 and freight_total>=0 and grand_total>=0)
);
create table public.erp_purchase_order_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 purchase_order_id uuid not null, item_id uuid not null, variant_id uuid, unit_id uuid not null,
 item_code_snapshot text not null, description_snapshot text not null, quantity numeric(19,6) not null check(quantity>0),
 unit_price numeric(19,4) not null check(unit_price>=0), discount_total numeric(19,4) not null default 0 check(discount_total>=0), line_total numeric(19,4) not null check(line_total>=0),
 created_at timestamptz not null default now(), unique(tenant_id,id),
 foreign key(tenant_id,purchase_order_id) references public.erp_purchase_orders(tenant_id,id) on delete cascade,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict
);
create table public.erp_goods_receipts (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 purchase_order_id uuid not null, location_id uuid not null, code text not null, status text not null default 'draft' check(status in('draft','posted','cancelled')),
 received_at timestamptz, stock_movement_id uuid, idempotency_key text not null, created_by uuid references auth.users(id), created_at timestamptz not null default now(),
 unique(tenant_id,code), unique(tenant_id,idempotency_key), unique(tenant_id,id),
 foreign key(tenant_id,purchase_order_id) references public.erp_purchase_orders(tenant_id,id) on delete restrict,
 foreign key(tenant_id,location_id) references public.erp_stock_locations(tenant_id,id) on delete restrict,
 foreign key(tenant_id,stock_movement_id) references public.erp_stock_movements(tenant_id,id) on delete restrict
);
create table public.erp_goods_receipt_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 goods_receipt_id uuid not null, purchase_order_item_id uuid not null, quantity numeric(19,6) not null check(quantity>0), lot_code text, serial_number text,
 created_at timestamptz not null default now(), unique(tenant_id,id),
 foreign key(tenant_id,goods_receipt_id) references public.erp_goods_receipts(tenant_id,id) on delete cascade,
 foreign key(tenant_id,purchase_order_item_id) references public.erp_purchase_order_items(tenant_id,id) on delete restrict
);

insert into public.erp_permissions(key,name,description,category) values
('pricing.read','Consultar preços','Consulta listas e promoções.','Preços'),('pricing.manage','Gerenciar preços','Mantém listas e promoções.','Preços'),
('stock.read','Consultar estoque','Consulta locais, saldos e movimentos.','Estoque'),('stock.manage','Gerenciar estoque','Cria e posta movimentos e reservas.','Estoque'),('stock.count','Realizar inventário','Conta e revisa inventários.','Estoque'),
('purchasing.read','Consultar compras','Consulta pedidos e recebimentos.','Compras'),('purchasing.manage','Gerenciar compras','Cria e aprova pedidos.','Compras'),('purchasing.receive','Receber compras','Registra recebimentos.','Compras')
on conflict(key) do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

do $$ declare t text; permission text; begin
 foreach t in array array['erp_price_lists','erp_price_items','erp_promotions'] loop permission:='pricing';
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''%s.read'')) or (select erp_security.has_permission(tenant_id,''%s.manage'')) or (select public.is_platform_staff()))',t||'_select',t,permission,permission);
  execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''%s.manage'')) or (select public.is_platform_staff()))',t||'_insert',t,permission);
  execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''%s.manage'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''%s.manage'')) or (select public.is_platform_staff()))',t||'_update',t,permission,permission);
 end loop;
 foreach t in array array['erp_stock_locations','erp_stock_lots','erp_stock_serials','erp_stock_movements','erp_stock_movement_items','erp_stock_reservations','erp_inventory_counts','erp_inventory_count_items'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''stock.read'')) or (select erp_security.has_permission(tenant_id,''stock.manage'')) or (select erp_security.has_permission(tenant_id,''stock.count'')) or (select public.is_platform_staff()))',t||'_select',t);
  execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''stock.manage'')) or (select erp_security.has_permission(tenant_id,''stock.count'')) or (select public.is_platform_staff()))',t||'_insert',t);
  if t not in('erp_stock_movements','erp_stock_movement_items') then execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''stock.manage'')) or (select erp_security.has_permission(tenant_id,''stock.count'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''stock.manage'')) or (select erp_security.has_permission(tenant_id,''stock.count'')) or (select public.is_platform_staff()))',t||'_update',t); end if;
 end loop;
 foreach t in array array['erp_purchase_orders','erp_purchase_order_items','erp_goods_receipts','erp_goods_receipt_items'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''purchasing.read'')) or (select erp_security.has_permission(tenant_id,''purchasing.manage'')) or (select erp_security.has_permission(tenant_id,''purchasing.receive'')) or (select public.is_platform_staff()))',t||'_select',t);
  execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''purchasing.manage'')) or (select erp_security.has_permission(tenant_id,''purchasing.receive'')) or (select public.is_platform_staff()))',t||'_insert',t);
  execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''purchasing.manage'')) or (select erp_security.has_permission(tenant_id,''purchasing.receive'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''purchasing.manage'')) or (select erp_security.has_permission(tenant_id,''purchasing.receive'')) or (select public.is_platform_staff()))',t||'_update',t);
 end loop;
end $$;

do $$ declare t text; begin
 foreach t in array array['erp_price_lists','erp_price_items','erp_promotions','erp_stock_locations','erp_stock_lots','erp_stock_serials','erp_stock_movements','erp_stock_movement_items','erp_stock_reservations','erp_inventory_counts','erp_inventory_count_items','erp_purchase_orders','erp_purchase_order_items','erp_goods_receipts','erp_goods_receipt_items'] loop
  execute format('revoke all on table public.%I from anon,authenticated',t);
  if t in('erp_stock_movements','erp_stock_movement_items') then execute format('grant select,insert on table public.%I to authenticated',t); else execute format('grant select,insert,update on table public.%I to authenticated',t); end if;
  execute format('grant all on table public.%I to service_role',t);
 end loop;
end $$;

commit;
