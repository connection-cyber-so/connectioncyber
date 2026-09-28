do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0040' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0040 para continuar.';
  end if;
end $$;
begin;

revoke execute on function
  public.erp_command_add_party_document_v1(uuid,text,text,jsonb),
  public.erp_command_add_party_contact_v1(uuid,text,text,jsonb),
  public.erp_command_add_party_address_v1(uuid,text,text,jsonb),
  public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb),
  public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb),
  public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)
from authenticated,service_role;

drop function if exists public.erp_command_add_party_document_v1(uuid,text,text,jsonb);
drop function if exists public.erp_command_add_party_contact_v1(uuid,text,text,jsonb);
drop function if exists public.erp_command_add_party_address_v1(uuid,text,text,jsonb);
drop function if exists public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb);
drop function if exists public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb);
drop function if exists public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb);

drop policy if exists erp_establishments_update_staff_or_manager on public.erp_establishments;

alter table public.erp_command_receipts drop constraint erp_command_receipts_command_type_check;
alter table public.erp_command_receipts add constraint erp_command_receipts_command_type_check
  check (command_type in ('party.create','catalog.item.create','inventory.receive','cash.open','sale.complete','finance.receivable.settle','cash.close'));

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

delete from public.erp_permissions where key = 'establishments.manage';

commit;
