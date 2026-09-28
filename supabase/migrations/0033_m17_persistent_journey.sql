-- ConnectionCyber — M17: fronteira transacional persistente da jornada ERP.
begin;

create table public.erp_command_receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  command_type text not null check (command_type in ('party.create','catalog.item.create','inventory.receive','cash.open','sale.complete','finance.receivable.settle','cash.close')),
  request_id text not null check (request_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{7,199}$'),
  payload_hash text not null check (payload_hash ~ '^[a-f0-9]{64}$'),
  status text not null default 'processing' check (status in ('processing','succeeded')),
  result_json jsonb,
  actor_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (tenant_id,command_type,request_id),
  unique (tenant_id,id),
  check ((status='processing' and result_json is null and completed_at is null) or (status='succeeded' and result_json is not null and completed_at is not null)),
  check (result_json is null or jsonb_typeof(result_json)='object')
);
create index erp_command_receipts_tenant_created on public.erp_command_receipts(tenant_id,created_at desc);
alter table public.erp_command_receipts enable row level security;
revoke all on table public.erp_command_receipts from public,anon,authenticated;
grant all on table public.erp_command_receipts to service_role;

create or replace function public.erp_require_command_access_v1(p_tenant_id uuid,p_permission text,p_capability text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception using errcode='42501',message='authentication required';end if;
  if not(erp_security.has_permission(p_tenant_id,p_permission)or public.is_platform_staff())then raise exception using errcode='42501',message='command access denied';end if;
  if not public.is_platform_staff() and not exists(select 1 from public.erp_resolve_tenant_capabilities(p_tenant_id,now())c where c.capability_key=p_capability and c.status in('trial','active'))then raise exception using errcode='42501',message='capability blocked';end if;
end$$;

create or replace function public.erp_claim_command_v1(p_tenant_id uuid,p_command_type text,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v public.erp_command_receipts%rowtype;v_computed_hash text;v_payload_text text;
begin
  if auth.uid() is null or p_tenant_id is null or p_command_type not in('party.create','catalog.item.create','inventory.receive','cash.open','sale.complete','finance.receivable.settle','cash.close')or p_request_id!~'^[A-Za-z0-9][A-Za-z0-9._:-]{7,199}$'or p_payload_hash!~'^[a-f0-9]{64}$'or jsonb_typeof(p_payload)<>'object'then raise exception using errcode='22023',message='invalid command envelope';end if;
  v_payload_text:=p_payload::text;if octet_length(v_payload_text)>65536 or v_payload_text~*'"(password|senha|secret|token|credential|private_key|service_role|certificate|certificado|pfx|p12|csc|id_token)"[[:space:]]*:'then raise exception using errcode='22023',message='unsafe command payload';end if;
  v_computed_hash:=encode(extensions.digest(convert_to(v_payload_text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||p_command_type||':'||p_request_id,0));
  select * into v from public.erp_command_receipts where tenant_id=p_tenant_id and command_type=p_command_type and request_id=p_request_id for update;
  if found then
    if v.payload_hash<>v_computed_hash then raise exception using errcode='23505',message='idempotency conflict';end if;
    if v.status='succeeded'then return jsonb_build_object('receiptId',v.id,'replayed',true,'result',v.result_json);end if;
    raise exception using errcode='40001',message='command already processing';
  end if;
  insert into public.erp_command_receipts(tenant_id,command_type,request_id,payload_hash,actor_id)values(p_tenant_id,p_command_type,p_request_id,v_computed_hash,auth.uid())returning * into v;
  return jsonb_build_object('receiptId',v.id,'replayed',false);
end$$;

create or replace function public.erp_complete_command_v1(p_tenant_id uuid,p_receipt_id uuid,p_result jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_result jsonb;
begin
  if jsonb_typeof(p_result)<>'object'then raise exception using errcode='22023',message='invalid command result';end if;
  update public.erp_command_receipts set status='succeeded',result_json=p_result,completed_at=now()where tenant_id=p_tenant_id and id=p_receipt_id and status='processing'and actor_id=auth.uid() returning result_json into v_result;
  if v_result is null then raise exception using errcode='40001',message='command receipt unavailable';end if;
  return v_result;
end$$;

create or replace function public.erp_command_create_party_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'parties.manage','core.parties');c:=public.erp_claim_command_v1(p_tenant_id,'party.create',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  v_id:=public.erp_create_party(p_tenant_id,p_payload->>'kind',p_payload->>'legalName',p_payload->>'tradeName',p_payload->>'taxId',p_payload->>'role');
  v_result:=jsonb_build_object('status','created','partyId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_create_catalog_item_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'catalog.manage','core.catalog');c:=public.erp_claim_command_v1(p_tenant_id,'catalog.item.create',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  insert into public.erp_catalog_items(tenant_id,kind,code,name,description,base_unit_id,track_inventory,allows_fraction,status,metadata)values(p_tenant_id,p_payload->>'kind',upper(btrim(p_payload->>'code')),btrim(p_payload->>'name'),nullif(btrim(p_payload->>'description'),''),(p_payload->>'baseUnitId')::uuid,coalesce((p_payload->>'trackInventory')::boolean,false),coalesce((p_payload->>'allowsFraction')::boolean,false),'active',coalesce(p_payload->'metadata','{}'::jsonb))returning id into v_id;
  v_result:=jsonb_build_object('status','created','itemId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_receive_inventory_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_qty numeric(19,6);v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'stock.manage','inventory.stock');c:=public.erp_claim_command_v1(p_tenant_id,'inventory.receive',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  v_qty:=(p_payload->>'quantity')::numeric;if v_qty<=0 then raise exception using errcode='22023',message='invalid quantity';end if;
  if not exists(select 1 from public.erp_catalog_items i where i.tenant_id=p_tenant_id and i.id=(p_payload->>'itemId')::uuid and i.track_inventory and i.status='active')or not exists(select 1 from public.erp_stock_locations l where l.tenant_id=p_tenant_id and l.id=(p_payload->>'locationId')::uuid and l.active)then raise exception using errcode='22023',message='inventory target unavailable';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||(p_payload->>'locationId')||':'||(p_payload->>'itemId')||':'||coalesce(p_payload->>'variantId',''),0));
  insert into public.erp_stock_movements(tenant_id,establishment_id,type,status,occurred_at,posted_at,source_type,idempotency_key,created_by)values(p_tenant_id,(p_payload->>'establishmentId')::uuid,'purchase_receipt','posted',now(),now(),'command',p_request_id||':stock',auth.uid())returning id into v_id;
  insert into public.erp_stock_movement_items(tenant_id,movement_id,location_id,item_id,variant_id,unit_id,quantity_delta,unit_cost)values(p_tenant_id,v_id,(p_payload->>'locationId')::uuid,(p_payload->>'itemId')::uuid,nullif(p_payload->>'variantId','')::uuid,(p_payload->>'unitId')::uuid,v_qty,nullif(p_payload->>'unitCost','')::numeric);
  v_result:=jsonb_build_object('status','received','stockMovementId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_open_cash_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'cash.operate','sales.pos');c:=public.erp_claim_command_v1(p_tenant_id,'cash.open',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_cash_registers r where r.tenant_id=p_tenant_id and r.id=(p_payload->>'cashRegisterId')::uuid and r.active)then raise exception using errcode='22023',message='cash register unavailable';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||(p_payload->>'cashRegisterId'),0));v_id:=public.erp_open_cash_session(p_tenant_id,(p_payload->>'cashRegisterId')::uuid,(p_payload->>'openingAmount')::numeric,p_request_id||':cash');
  v_result:=jsonb_build_object('status','opened','cashSessionId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_complete_sale_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;v_sale public.erp_sales%rowtype;v_credit numeric(19,4);v_due date;v_entry_id uuid;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'sales.complete','sales.pos');c:=public.erp_claim_command_v1(p_tenant_id,'sale.complete',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  v_id:=(p_payload->>'saleId')::uuid;perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||v_id::text,0));v_id:=public.erp_complete_sale(p_tenant_id,v_id,p_payload->>'saleIdempotencyKey');
  select * into strict v_sale from public.erp_sales where tenant_id=p_tenant_id and id=v_id;
  select coalesce(sum(sp.amount),0) into v_credit from public.erp_sale_payments sp join public.erp_payment_methods pm on pm.tenant_id=sp.tenant_id and pm.id=sp.payment_method_id where sp.tenant_id=p_tenant_id and sp.sale_id=v_id and sp.status='captured' and pm.kind='store_credit';
  if v_credit>0 then
    if v_sale.customer_id is null then raise exception using errcode='22023',message='customer required for store credit';end if;
    if v_credit<>v_sale.grand_total then raise exception using errcode='22023',message='mixed store credit projection unsupported';end if;
    if coalesce(p_payload->>'dueDate','')!~'^\d{4}-\d{2}-\d{2}$' then raise exception using errcode='22023',message='dueDate required for store credit';end if;
    v_due:=(p_payload->>'dueDate')::date;
    insert into public.erp_financial_entries(tenant_id,establishment_id,party_id,code,direction,status,currency_code,principal_amount,issue_date,due_date,source_type,source_id,idempotency_key,created_by)
    values(p_tenant_id,v_sale.establishment_id,v_sale.customer_id,v_sale.code||'-REC','receivable','open',v_sale.currency_code,v_credit,current_date,v_due,'sale',v_id,p_request_id||':receivable',auth.uid()) returning id into v_entry_id;
    insert into public.erp_installments(tenant_id,financial_entry_id,number,status,due_date,principal_amount) values(p_tenant_id,v_entry_id,1,'open',v_due,v_credit);
  end if;
  v_result:=jsonb_build_object('status','completed','saleId',v_id,'financialEntryId',v_entry_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_settle_receivable_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'finance.settle','finance');c:=public.erp_claim_command_v1(p_tenant_id,'finance.receivable.settle',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  v_id:=(p_payload->>'settlementId')::uuid;perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||v_id::text,0));v_id:=public.erp_confirm_settlement(p_tenant_id,v_id,p_payload->>'settlementIdempotencyKey');
  v_result:=jsonb_build_object('status','settled','settlementId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_close_cash_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v public.erp_cash_sessions%rowtype;v_expected numeric(19,4);v_counted numeric(19,4);v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'cash.close','sales.pos');c:=public.erp_claim_command_v1(p_tenant_id,'cash.close',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||(p_payload->>'cashSessionId'),0));select * into v from public.erp_cash_sessions where tenant_id=p_tenant_id and id=(p_payload->>'cashSessionId')::uuid for update;if not found then raise exception using errcode='P0002',message='cash session not found';end if;if v.status='closed'then raise exception using errcode='55000',message='cash session already closed';end if;
  select v.opening_amount+coalesce(sum(case when m.direction='in'then m.amount else-m.amount end),0)into v_expected from public.erp_cash_movements m where m.tenant_id=p_tenant_id and m.cash_session_id=v.id and m.type<>'opening';v_counted:=(p_payload->>'countedAmount')::numeric;if v_counted<>v_expected then raise exception using errcode='23514',message='cash difference';end if;
  update public.erp_cash_sessions set status='closed',closed_at=now(),expected_amount=v_expected,counted_amount=v_counted,difference_amount=0 where tenant_id=p_tenant_id and id=v.id;
  v_result:=jsonb_build_object('status','closed','cashSessionId',v.id,'expectedAmount',v_expected);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

revoke execute on function public.erp_require_command_access_v1(uuid,text,text),public.erp_claim_command_v1(uuid,text,text,text,jsonb),public.erp_complete_command_v1(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.erp_require_command_access_v1(uuid,text,text),public.erp_claim_command_v1(uuid,text,text,text,jsonb),public.erp_complete_command_v1(uuid,uuid,jsonb) to service_role;
revoke execute on function public.erp_command_create_party_v1(uuid,text,text,jsonb),public.erp_command_create_catalog_item_v1(uuid,text,text,jsonb),public.erp_command_receive_inventory_v1(uuid,text,text,jsonb),public.erp_command_open_cash_v1(uuid,text,text,jsonb),public.erp_command_complete_sale_v1(uuid,text,text,jsonb),public.erp_command_settle_receivable_v1(uuid,text,text,jsonb),public.erp_command_close_cash_v1(uuid,text,text,jsonb) from public,anon;
grant execute on function public.erp_command_create_party_v1(uuid,text,text,jsonb),public.erp_command_create_catalog_item_v1(uuid,text,text,jsonb),public.erp_command_receive_inventory_v1(uuid,text,text,jsonb),public.erp_command_open_cash_v1(uuid,text,text,jsonb),public.erp_command_complete_sale_v1(uuid,text,text,jsonb),public.erp_command_settle_receivable_v1(uuid,text,text,jsonb),public.erp_command_close_cash_v1(uuid,text,text,jsonb) to authenticated,service_role;

commit;
