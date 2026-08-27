-- ConnectionCyber — M07: orçamentos, pedidos, vendas, pagamentos, caixa e PDV.
begin;

create table public.erp_quotes (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, customer_id uuid, code text not null, status text not null default 'draft' check(status in('draft','sent','accepted','rejected','expired','cancelled')),
 currency_code text not null default 'BRL' check(currency_code~'^[A-Z]{3}$'), valid_until timestamptz, subtotal numeric(19,4) not null default 0,
 discount_total numeric(19,4) not null default 0, surcharge_total numeric(19,4) not null default 0, grand_total numeric(19,4) not null default 0,
 version integer not null default 1 check(version>0), notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tenant_id,code,version), unique(tenant_id,id), foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict,
 foreign key(tenant_id,customer_id) references public.erp_parties(tenant_id,id) on delete restrict,
 check(subtotal>=0 and discount_total>=0 and surcharge_total>=0 and grand_total>=0)
);
create table public.erp_quote_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 quote_id uuid not null, item_id uuid not null, variant_id uuid, unit_id uuid not null, item_code_snapshot text not null, description_snapshot text not null,
 quantity numeric(19,6) not null check(quantity>0), unit_price numeric(19,4) not null check(unit_price>=0), discount_total numeric(19,4) not null default 0 check(discount_total>=0),
 surcharge_total numeric(19,4) not null default 0 check(surcharge_total>=0), line_total numeric(19,4) not null check(line_total>=0), sort_order integer not null default 0,
 created_at timestamptz not null default now(), unique(tenant_id,id), foreign key(tenant_id,quote_id) references public.erp_quotes(tenant_id,id) on delete cascade,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict
);
create table public.erp_sales_orders (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, customer_id uuid, quote_id uuid, code text not null, status text not null default 'draft' check(status in('draft','confirmed','partially_fulfilled','fulfilled','cancelled')),
 currency_code text not null default 'BRL' check(currency_code~'^[A-Z]{3}$'), subtotal numeric(19,4) not null default 0, discount_total numeric(19,4) not null default 0,
 surcharge_total numeric(19,4) not null default 0, grand_total numeric(19,4) not null default 0, confirmed_at timestamptz, notes text,
 created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,id),
 foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict,
 foreign key(tenant_id,customer_id) references public.erp_parties(tenant_id,id) on delete restrict,
 foreign key(tenant_id,quote_id) references public.erp_quotes(tenant_id,id) on delete restrict,
 check(subtotal>=0 and discount_total>=0 and surcharge_total>=0 and grand_total>=0)
);
create table public.erp_sales_order_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 sales_order_id uuid not null, item_id uuid not null, variant_id uuid, unit_id uuid not null, item_code_snapshot text not null, description_snapshot text not null,
 quantity numeric(19,6) not null check(quantity>0), fulfilled_quantity numeric(19,6) not null default 0 check(fulfilled_quantity>=0 and fulfilled_quantity<=quantity),
 unit_price numeric(19,4) not null check(unit_price>=0), discount_total numeric(19,4) not null default 0 check(discount_total>=0), surcharge_total numeric(19,4) not null default 0 check(surcharge_total>=0),
 line_total numeric(19,4) not null check(line_total>=0), created_at timestamptz not null default now(), unique(tenant_id,id),
 foreign key(tenant_id,sales_order_id) references public.erp_sales_orders(tenant_id,id) on delete cascade,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict
);

create table public.erp_payment_methods (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 code text not null, name text not null, kind text not null check(kind in('cash','pix','credit_card','debit_card','voucher','store_credit','other')),
 provider text, allows_change boolean not null default false, requires_external_reference boolean not null default false, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,id),
 check(not allows_change or kind='cash')
);
create table public.erp_cash_registers (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, code text not null, name text not null, active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,id),
 foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict
);
create table public.erp_cash_sessions (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 cash_register_id uuid not null, operator_id uuid not null references auth.users(id), status text not null default 'open' check(status in('open','closing','closed')),
 opened_at timestamptz not null default now(), closed_at timestamptz, opening_amount numeric(19,4) not null default 0 check(opening_amount>=0),
 expected_amount numeric(19,4), counted_amount numeric(19,4), difference_amount numeric(19,4), idempotency_key text not null,
 created_at timestamptz not null default now(), unique(tenant_id,idempotency_key), unique(tenant_id,id),
 foreign key(tenant_id,cash_register_id) references public.erp_cash_registers(tenant_id,id) on delete restrict,
 check((status='closed' and closed_at is not null and counted_amount is not null) or status<>'closed')
);
create unique index erp_cash_sessions_one_open on public.erp_cash_sessions(tenant_id,cash_register_id) where status in('open','closing');

create table public.erp_sales (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 establishment_id uuid not null, customer_id uuid, sales_order_id uuid, cash_session_id uuid, price_list_id uuid, code text not null,
 status text not null default 'draft' check(status in('draft','completed','partially_returned','returned','voided')),
 currency_code text not null default 'BRL' check(currency_code~'^[A-Z]{3}$'), subtotal numeric(19,4) not null default 0, discount_total numeric(19,4) not null default 0,
 surcharge_total numeric(19,4) not null default 0, grand_total numeric(19,4) not null default 0, change_total numeric(19,4) not null default 0,
 completed_at timestamptz, stock_movement_id uuid, idempotency_key text not null, created_by uuid references auth.users(id), created_at timestamptz not null default now(),
 unique(tenant_id,code), unique(tenant_id,idempotency_key), unique(tenant_id,id),
 foreign key(tenant_id,establishment_id) references public.erp_establishments(tenant_id,id) on delete restrict,
 foreign key(tenant_id,customer_id) references public.erp_parties(tenant_id,id) on delete restrict,
 foreign key(tenant_id,sales_order_id) references public.erp_sales_orders(tenant_id,id) on delete restrict,
 foreign key(tenant_id,cash_session_id) references public.erp_cash_sessions(tenant_id,id) on delete restrict,
 foreign key(tenant_id,price_list_id) references public.erp_price_lists(tenant_id,id) on delete restrict,
 foreign key(tenant_id,stock_movement_id) references public.erp_stock_movements(tenant_id,id) on delete restrict,
 check(subtotal>=0 and discount_total>=0 and surcharge_total>=0 and grand_total>=0 and change_total>=0),
 check((status='draft' and completed_at is null) or (status<>'draft' and completed_at is not null))
);
create table public.erp_sale_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 sale_id uuid not null, item_id uuid not null, variant_id uuid, unit_id uuid not null, stock_location_id uuid,
 item_code_snapshot text not null, description_snapshot text not null, quantity numeric(19,6) not null check(quantity>0), unit_price numeric(19,4) not null check(unit_price>=0),
 discount_total numeric(19,4) not null default 0 check(discount_total>=0), surcharge_total numeric(19,4) not null default 0 check(surcharge_total>=0), line_total numeric(19,4) not null check(line_total>=0),
 created_at timestamptz not null default now(), unique(tenant_id,id), foreign key(tenant_id,sale_id) references public.erp_sales(tenant_id,id) on delete cascade,
 foreign key(tenant_id,item_id) references public.erp_catalog_items(tenant_id,id) on delete restrict,
 foreign key(tenant_id,item_id,variant_id) references public.erp_item_variants(tenant_id,item_id,id) on delete restrict,
 foreign key(tenant_id,unit_id) references public.erp_units(tenant_id,id) on delete restrict,
 foreign key(tenant_id,stock_location_id) references public.erp_stock_locations(tenant_id,id) on delete restrict
);
create table public.erp_sale_payments (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 sale_id uuid not null, payment_method_id uuid not null, status text not null default 'pending' check(status in('pending','authorized','captured','failed','cancelled','refunded')),
 amount numeric(19,4) not null check(amount>0), provider text, external_id text, idempotency_key text not null, captured_at timestamptz,
 created_at timestamptz not null default now(), unique(tenant_id,idempotency_key), unique nulls not distinct(tenant_id,provider,external_id), unique(tenant_id,id),
 foreign key(tenant_id,sale_id) references public.erp_sales(tenant_id,id) on delete cascade,
 foreign key(tenant_id,payment_method_id) references public.erp_payment_methods(tenant_id,id) on delete restrict,
 check((status='captured' and captured_at is not null) or status<>'captured')
);
create table public.erp_cash_movements (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 cash_session_id uuid not null, type text not null check(type in('opening','sale','supply','withdrawal','refund','adjustment','closing')),
 direction text not null check(direction in('in','out')), amount numeric(19,4) not null check(amount>0), sale_payment_id uuid, reason text,
 idempotency_key text not null, occurred_at timestamptz not null default now(), created_by uuid references auth.users(id), created_at timestamptz not null default now(),
 unique(tenant_id,idempotency_key), unique(tenant_id,id), foreign key(tenant_id,cash_session_id) references public.erp_cash_sessions(tenant_id,id) on delete restrict,
 foreign key(tenant_id,sale_payment_id) references public.erp_sale_payments(tenant_id,id) on delete restrict
);

create table public.erp_returns (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 sale_id uuid not null, code text not null, status text not null default 'draft' check(status in('draft','completed','cancelled')),
 total numeric(19,4) not null default 0 check(total>=0), stock_movement_id uuid, idempotency_key text not null, reason text not null,
 completed_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now(), unique(tenant_id,code), unique(tenant_id,idempotency_key), unique(tenant_id,id),
 foreign key(tenant_id,sale_id) references public.erp_sales(tenant_id,id) on delete restrict,
 foreign key(tenant_id,stock_movement_id) references public.erp_stock_movements(tenant_id,id) on delete restrict
);
create table public.erp_return_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 return_id uuid not null, sale_item_id uuid not null, quantity numeric(19,6) not null check(quantity>0), amount numeric(19,4) not null check(amount>=0),
 created_at timestamptz not null default now(), unique(tenant_id,id), foreign key(tenant_id,return_id) references public.erp_returns(tenant_id,id) on delete cascade,
 foreign key(tenant_id,sale_item_id) references public.erp_sale_items(tenant_id,id) on delete restrict
);
create table public.erp_sale_receipts (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 sale_id uuid not null, receipt_number text not null, content text not null, content_hash text not null check(content_hash~'^[a-f0-9]{64}$'), issued_at timestamptz not null default now(),
 reprint_count integer not null default 0 check(reprint_count>=0), created_at timestamptz not null default now(), unique(tenant_id,receipt_number), unique(tenant_id,id),
 foreign key(tenant_id,sale_id) references public.erp_sales(tenant_id,id) on delete restrict
);

insert into public.erp_permissions(key,name,description,category) values
('sales.read','Consultar vendas','Consulta orçamentos, pedidos e vendas.','Vendas'),('sales.quote','Gerenciar orçamentos','Cria e altera orçamentos.','Vendas'),
('sales.order','Gerenciar pedidos','Cria e confirma pedidos.','Vendas'),('sales.complete','Concluir vendas','Fecha vendas atomicamente.','Vendas'),
('sales.return','Registrar devoluções','Registra devoluções por contrapartida.','Vendas'),('sales.discount','Autorizar descontos','Autoriza descontos excepcionais.','Vendas'),
('payments.read','Consultar pagamentos','Consulta pagamentos ERP.','Pagamentos'),('payments.manage','Gerenciar pagamentos','Autoriza e captura pagamentos.','Pagamentos'),
('payments.refund','Estornar pagamentos','Registra estornos de pagamentos.','Pagamentos'),('cash.read','Consultar caixa','Consulta sessões e movimentos.','Caixa'),
('cash.operate','Operar caixa','Abre caixa e registra movimentos.','Caixa'),('cash.close','Fechar caixa','Confere e fecha sessões.','Caixa'),('cash.adjust','Ajustar caixa','Registra ajustes auditados.','Caixa')
on conflict(key) do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

create or replace function public.erp_open_cash_session(p_tenant_id uuid,p_cash_register_id uuid,p_opening_amount numeric,p_idempotency_key text) returns uuid
language plpgsql security definer set search_path='' as $$ declare v_id uuid; begin
 if not (erp_security.has_permission(p_tenant_id,'cash.operate') or public.is_platform_staff()) then raise exception 'permission denied'; end if;
 select id into v_id from public.erp_cash_sessions where tenant_id=p_tenant_id and idempotency_key=p_idempotency_key;
 if v_id is not null then return v_id; end if;
 insert into public.erp_cash_sessions(tenant_id,cash_register_id,operator_id,opening_amount,idempotency_key) values(p_tenant_id,p_cash_register_id,auth.uid(),p_opening_amount,p_idempotency_key) returning id into v_id;
 if p_opening_amount>0 then insert into public.erp_cash_movements(tenant_id,cash_session_id,type,direction,amount,reason,idempotency_key,created_by) values(p_tenant_id,v_id,'opening','in',p_opening_amount,'Abertura',p_idempotency_key||':opening',auth.uid()); end if;
 return v_id; end $$;

create or replace function public.erp_complete_sale(p_tenant_id uuid,p_sale_id uuid,p_idempotency_key text) returns uuid
language plpgsql security definer set search_path='' as $$ declare v_sale public.erp_sales%rowtype; v_sub numeric(19,4);v_disc numeric(19,4);v_surch numeric(19,4);v_total numeric(19,4);v_paid numeric(19,4);v_stock uuid; r record; begin
 if not (erp_security.has_permission(p_tenant_id,'sales.complete') or public.is_platform_staff()) then raise exception 'permission denied'; end if;
 select * into v_sale from public.erp_sales where tenant_id=p_tenant_id and id=p_sale_id for update;
 if not found then raise exception 'sale not found'; end if; if v_sale.status='completed' then return v_sale.id; end if; if v_sale.status<>'draft' then raise exception 'invalid sale status'; end if;
 if v_sale.idempotency_key<>p_idempotency_key then raise exception 'idempotency mismatch'; end if;
 select coalesce(sum(quantity*unit_price),0),coalesce(sum(discount_total),0),coalesce(sum(surcharge_total),0),coalesce(sum(line_total),0) into v_sub,v_disc,v_surch,v_total from public.erp_sale_items where tenant_id=p_tenant_id and sale_id=p_sale_id;
 if v_total<>v_sub-v_disc+v_surch or v_total<=0 then raise exception 'invalid totals'; end if;
 if v_sale.price_list_id is null and not erp_security.has_permission(p_tenant_id,'sales.discount') then raise exception 'server price list required'; end if;
 if v_sale.price_list_id is not null and exists(
  select 1 from public.erp_sale_items si where si.tenant_id=p_tenant_id and si.sale_id=p_sale_id and not exists(
   select 1 from public.erp_price_items pi where pi.tenant_id=si.tenant_id and pi.price_list_id=v_sale.price_list_id and pi.item_id=si.item_id
    and pi.variant_id is not distinct from si.variant_id and pi.unit_id=si.unit_id and pi.min_quantity<=si.quantity and pi.price=si.unit_price
    and (pi.valid_from is null or pi.valid_from<=now()) and (pi.valid_until is null or pi.valid_until>now())
  )
 ) and not erp_security.has_permission(p_tenant_id,'sales.discount') then raise exception 'price not authorized'; end if;
 select coalesce(sum(amount),0) into v_paid from public.erp_sale_payments where tenant_id=p_tenant_id and sale_id=p_sale_id and status='captured'; if v_paid<v_total then raise exception 'insufficient payment'; end if;
 if exists(select 1 from public.erp_sale_items si join public.erp_catalog_items ci on ci.tenant_id=si.tenant_id and ci.id=si.item_id where si.tenant_id=p_tenant_id and si.sale_id=p_sale_id and ci.track_inventory and si.stock_location_id is null) then raise exception 'stock location required'; end if;
 for r in select si.stock_location_id,si.item_id,si.variant_id,si.quantity from public.erp_sale_items si join public.erp_catalog_items ci on ci.tenant_id=si.tenant_id and ci.id=si.item_id where si.tenant_id=p_tenant_id and si.sale_id=p_sale_id and ci.track_inventory order by si.stock_location_id,si.item_id,si.variant_id nulls first loop
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||r.stock_location_id::text||':'||r.item_id::text||':'||coalesce(r.variant_id::text,''),0));
  if not (select allows_negative from public.erp_stock_locations where tenant_id=p_tenant_id and id=r.stock_location_id) and
   (coalesce((select sum(smi.quantity_delta) from public.erp_stock_movement_items smi join public.erp_stock_movements sm on sm.tenant_id=smi.tenant_id and sm.id=smi.movement_id where smi.tenant_id=p_tenant_id and smi.location_id=r.stock_location_id and smi.item_id=r.item_id and smi.variant_id is not distinct from r.variant_id and sm.status='posted'),0)
    -coalesce((select sum(sr.quantity) from public.erp_stock_reservations sr where sr.tenant_id=p_tenant_id and sr.location_id=r.stock_location_id and sr.item_id=r.item_id and sr.variant_id is not distinct from r.variant_id and sr.status='active' and (sr.expires_at is null or sr.expires_at>now())),0))<r.quantity then raise exception 'insufficient stock'; end if;
 end loop;
 if exists(select 1 from public.erp_sale_items si join public.erp_catalog_items ci on ci.tenant_id=si.tenant_id and ci.id=si.item_id where si.tenant_id=p_tenant_id and si.sale_id=p_sale_id and ci.track_inventory) then
  insert into public.erp_stock_movements(tenant_id,establishment_id,type,status,occurred_at,posted_at,source_type,source_id,idempotency_key,created_by) values(p_tenant_id,v_sale.establishment_id,'sale','posted',now(),now(),'sale',p_sale_id,p_idempotency_key||':stock',auth.uid()) returning id into v_stock;
  insert into public.erp_stock_movement_items(tenant_id,movement_id,location_id,item_id,variant_id,unit_id,quantity_delta) select si.tenant_id,v_stock,si.stock_location_id,si.item_id,si.variant_id,si.unit_id,-si.quantity from public.erp_sale_items si join public.erp_catalog_items ci on ci.tenant_id=si.tenant_id and ci.id=si.item_id where si.tenant_id=p_tenant_id and si.sale_id=p_sale_id and ci.track_inventory;
 end if;
 for r in select sp.id,sp.amount,pm.kind from public.erp_sale_payments sp join public.erp_payment_methods pm on pm.tenant_id=sp.tenant_id and pm.id=sp.payment_method_id where sp.tenant_id=p_tenant_id and sp.sale_id=p_sale_id and sp.status='captured' and pm.kind='cash' loop
  if v_sale.cash_session_id is null then raise exception 'cash session required'; end if;
  insert into public.erp_cash_movements(tenant_id,cash_session_id,type,direction,amount,sale_payment_id,idempotency_key,created_by) values(p_tenant_id,v_sale.cash_session_id,'sale','in',r.amount,r.id,p_idempotency_key||':cash:'||r.id,auth.uid());
 end loop;
 update public.erp_sales set status='completed',subtotal=v_sub,discount_total=v_disc,surcharge_total=v_surch,grand_total=v_total,change_total=v_paid-v_total,completed_at=now(),stock_movement_id=v_stock where tenant_id=p_tenant_id and id=p_sale_id;
 return p_sale_id; end $$;

do $$ declare t text; begin
 foreach t in array array['erp_quotes','erp_quote_items'] loop
  execute format('alter table public.%I enable row level security',t); execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''sales.read'')) or (select erp_security.has_permission(tenant_id,''sales.quote'')) or (select public.is_platform_staff()))',t||'_select',t);
  execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''sales.quote'')) or (select public.is_platform_staff()))',t||'_insert',t);
  execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''sales.quote'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''sales.quote'')) or (select public.is_platform_staff()))',t||'_update',t);
 end loop;
 foreach t in array array['erp_sales_orders','erp_sales_order_items'] loop
  execute format('alter table public.%I enable row level security',t); execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''sales.read'')) or (select erp_security.has_permission(tenant_id,''sales.order'')) or (select public.is_platform_staff()))',t||'_select',t);
  execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''sales.order'')) or (select public.is_platform_staff()))',t||'_insert',t);
  execute format('create policy %I on public.%I for update to authenticated using ((select erp_security.has_permission(tenant_id,''sales.order'')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,''sales.order'')) or (select public.is_platform_staff()))',t||'_update',t);
 end loop;
 foreach t in array array['erp_sales','erp_sale_items','erp_sale_receipts'] loop execute format('alter table public.%I enable row level security',t); execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''sales.read'')) or (select erp_security.has_permission(tenant_id,''sales.complete'')) or (select public.is_platform_staff()))',t||'_select',t); execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''sales.complete'')) or (select public.is_platform_staff()))',t||'_insert',t); end loop;
 foreach t in array array['erp_returns','erp_return_items'] loop execute format('alter table public.%I enable row level security',t); execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''sales.read'')) or (select erp_security.has_permission(tenant_id,''sales.return'')) or (select public.is_platform_staff()))',t||'_select',t); execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''sales.return'')) or (select public.is_platform_staff()))',t||'_insert',t); end loop;
 foreach t in array array['erp_payment_methods','erp_sale_payments'] loop execute format('alter table public.%I enable row level security',t); execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''payments.read'')) or (select erp_security.has_permission(tenant_id,''payments.manage'')) or (select public.is_platform_staff()))',t||'_select',t); execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''payments.manage'')) or (select public.is_platform_staff()))',t||'_insert',t); end loop;
 foreach t in array array['erp_cash_registers','erp_cash_sessions','erp_cash_movements'] loop execute format('alter table public.%I enable row level security',t); execute format('create policy %I on public.%I for select to authenticated using ((select erp_security.has_permission(tenant_id,''cash.read'')) or (select erp_security.has_permission(tenant_id,''cash.operate'')) or (select public.is_platform_staff()))',t||'_select',t); execute format('create policy %I on public.%I for insert to authenticated with check ((select erp_security.has_permission(tenant_id,''cash.operate'')) or (select public.is_platform_staff()))',t||'_insert',t); end loop;
end $$;

create policy erp_payment_methods_update on public.erp_payment_methods for update to authenticated using ((select erp_security.has_permission(tenant_id,'payments.manage')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,'payments.manage')) or (select public.is_platform_staff()));
create policy erp_cash_registers_update on public.erp_cash_registers for update to authenticated using ((select erp_security.has_permission(tenant_id,'cash.operate')) or (select public.is_platform_staff())) with check ((select erp_security.has_permission(tenant_id,'cash.operate')) or (select public.is_platform_staff()));

do $$ declare t text; begin foreach t in array array['erp_quotes','erp_quote_items','erp_sales_orders','erp_sales_order_items','erp_sales','erp_sale_items','erp_returns','erp_return_items','erp_sale_receipts','erp_payment_methods','erp_sale_payments','erp_cash_registers','erp_cash_sessions','erp_cash_movements'] loop execute format('revoke all on table public.%I from anon,authenticated',t); if t in('erp_quotes','erp_quote_items','erp_sales_orders','erp_sales_order_items','erp_payment_methods','erp_cash_registers') then execute format('grant select,insert,update on table public.%I to authenticated',t); else execute format('grant select,insert on table public.%I to authenticated',t); end if; execute format('grant all on table public.%I to service_role',t); end loop; end $$;
revoke execute on function public.erp_open_cash_session(uuid,uuid,numeric,text),public.erp_complete_sale(uuid,uuid,text) from public,anon;
grant execute on function public.erp_open_cash_session(uuid,uuid,numeric,text),public.erp_complete_sale(uuid,uuid,text) to authenticated,service_role;
commit;
