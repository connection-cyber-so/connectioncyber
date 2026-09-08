-- ConnectionCyber — M21-G1 (Trilha A): implementa de verdade os 6 comandos de escrita
-- do M20-VISUAL-2.0 que hoje só existem no contrato (packages/visual-persistence-contract)
-- e no transporte síntetico (apps/platform/src/features/persistence/local.ts) — nunca
-- ganharam a função SQL correspondente. Sem isso, RPC_ALLOWLIST não pode crescer de 7
-- para 13 sem quebrar (a função não existiria no banco).
--
-- Mesmo padrão de envelope idempotente do M17 (migration 0033): permissão+capacidade via
-- erp_require_command_access_v1, claim/complete via erp_claim_command_v1/erp_complete_command_v1,
-- lock consultivo por chave de negócio, payload jsonb validado dentro da função.
--
-- Decisão de escopo: registra as permissões novas necessárias (parties.manage e
-- catalog.manage já existem desde o M05; fiscal.item.manage já existe desde o M20-G1;
-- só falta establishments.manage, que nunca existiu porque erp_establishments nunca teve
-- via de escrita nenhuma além de migration/seed). Não anexa nenhuma permissão nova a
-- nenhum papel (erp_role_permissions) — por enquanto só quem tem is_platform_staff()=true
-- consegue executar estes comandos, mesmo padrão deixado em aberto pelo M20-G1 pra
-- fiscal.item.manage. Abrir para o próprio dono do tenant é trabalho da Trilha B
-- (M05 real do apps/portal), não deste gate.
begin;

-- 1. Permissão nova para o único comando que não tinha nenhuma via de escrita ainda.
insert into public.erp_permissions(key,name,description,category) values
('establishments.manage','Gerenciar estabelecimentos','Altera dados operacionais do estabelecimento, incluindo a vertical de negócio.','Organização')
on conflict (key) do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

-- 2. RLS defensiva em profundidade para erp_establishments — hoje só tem SELECT.
--    A função SECURITY DEFINER abaixo não depende desta policy pra funcionar (roda como
--    dono da tabela), mas nenhuma tabela do projeto deveria ficar sem nenhuma política de
--    escrita registrada, mesmo que hoje só platform staff consiga de fato usá-la.
create policy erp_establishments_update_staff_or_manager
  on public.erp_establishments for update to authenticated
  using ((select erp_security.has_permission(tenant_id,'establishments.manage')) or (select public.is_platform_staff()))
  with check ((select erp_security.has_permission(tenant_id,'establishments.manage')) or (select public.is_platform_staff()));

-- 3. Amplia o envelope idempotente do M17 para os 6 novos tipos de comando.
alter table public.erp_command_receipts drop constraint erp_command_receipts_command_type_check;
alter table public.erp_command_receipts add constraint erp_command_receipts_command_type_check
  check (command_type in (
    'party.create','catalog.item.create','inventory.receive','cash.open','sale.complete',
    'finance.receivable.settle','cash.close',
    'party.document.add','party.contact.add','party.address.add',
    'catalog.item.fiscal.set','catalog.item.commercial.set','establishment.vertical.set'
  ));

create or replace function public.erp_claim_command_v1(p_tenant_id uuid,p_command_type text,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v public.erp_command_receipts%rowtype;v_computed_hash text;v_payload_text text;
begin
  if auth.uid() is null or p_tenant_id is null or p_command_type not in(
    'party.create','catalog.item.create','inventory.receive','cash.open','sale.complete',
    'finance.receivable.settle','cash.close',
    'party.document.add','party.contact.add','party.address.add',
    'catalog.item.fiscal.set','catalog.item.commercial.set','establishment.vertical.set'
  )or p_request_id!~'^[A-Za-z0-9][A-Za-z0-9._:-]{7,199}$'or p_payload_hash!~'^[a-f0-9]{64}$'or jsonb_typeof(p_payload)<>'object'then raise exception using errcode='22023',message='invalid command envelope';end if;
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

-- 4. Os 6 comandos novos. Nomes de RPC batem exatamente com COMMAND_BOUNDARIES em
--    packages/visual-persistence-contract/src/index.mjs (M20-G3) — já validado por
--    validateVisualPersistenceContract() e pelos 192 testes de apps/platform.

create or replace function public.erp_command_add_party_document_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'parties.manage','core.parties');c:=public.erp_claim_command_v1(p_tenant_id,'party.document.add',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_parties p where p.tenant_id=p_tenant_id and p.id=(p_payload->>'partyId')::uuid)then raise exception using errcode='22023',message='party not found';end if;
  insert into public.erp_party_documents(tenant_id,party_id,type,number,issuer,issued_at,expires_at)
  values(p_tenant_id,(p_payload->>'partyId')::uuid,p_payload->>'type',btrim(p_payload->>'number'),nullif(btrim(p_payload->>'issuer'),''),nullif(p_payload->>'issuedAt','')::date,nullif(p_payload->>'expiresAt','')::date)
  returning id into v_id;
  v_result:=jsonb_build_object('status','created','documentId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_add_party_contact_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'parties.manage','core.parties');c:=public.erp_claim_command_v1(p_tenant_id,'party.contact.add',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_parties p where p.tenant_id=p_tenant_id and p.id=(p_payload->>'partyId')::uuid)then raise exception using errcode='22023',message='party not found';end if;
  insert into public.erp_party_contacts(tenant_id,party_id,type,value,label,is_primary)
  values(p_tenant_id,(p_payload->>'partyId')::uuid,p_payload->>'type',btrim(p_payload->>'value'),nullif(btrim(p_payload->>'label'),''),coalesce((p_payload->>'isPrimary')::boolean,false))
  returning id into v_id;
  v_result:=jsonb_build_object('status','created','contactId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_add_party_address_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'parties.manage','core.parties');c:=public.erp_claim_command_v1(p_tenant_id,'party.address.add',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_parties p where p.tenant_id=p_tenant_id and p.id=(p_payload->>'partyId')::uuid)then raise exception using errcode='22023',message='party not found';end if;
  insert into public.erp_party_addresses(tenant_id,party_id,type,postal_code,street,number,complement,district,city,state_code,is_primary)
  values(p_tenant_id,(p_payload->>'partyId')::uuid,p_payload->>'type',nullif(btrim(p_payload->>'postalCode'),''),btrim(p_payload->>'street'),nullif(btrim(p_payload->>'number'),''),nullif(btrim(p_payload->>'complement'),''),nullif(btrim(p_payload->>'district'),''),btrim(p_payload->>'city'),nullif(upper(btrim(p_payload->>'stateCode')),''),coalesce((p_payload->>'isPrimary')::boolean,false))
  returning id into v_id;
  v_result:=jsonb_build_object('status','created','addressId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_set_item_fiscal_data_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'fiscal.item.manage','fiscal');c:=public.erp_claim_command_v1(p_tenant_id,'catalog.item.fiscal.set',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_catalog_items i where i.tenant_id=p_tenant_id and i.id=(p_payload->>'itemId')::uuid)then raise exception using errcode='22023',message='item not found';end if;
  insert into public.erp_item_fiscal_data(tenant_id,item_id,ncm,cest,origin,tax_code_kind,tax_code,icms_rate,icms_base_percent,ipi_rate,gross_weight,net_weight)
  values(p_tenant_id,(p_payload->>'itemId')::uuid,p_payload->>'ncm',nullif(p_payload->>'cest',''),coalesce((p_payload->>'origin')::int,0),p_payload->>'taxCodeKind',p_payload->>'taxCode',coalesce((p_payload->>'icmsRate')::numeric,0),coalesce((p_payload->>'icmsBasePercent')::numeric,100),coalesce((p_payload->>'ipiRate')::numeric,0),nullif(p_payload->>'grossWeight','')::numeric,nullif(p_payload->>'netWeight','')::numeric)
  on conflict(tenant_id,item_id) do update set ncm=excluded.ncm,cest=excluded.cest,origin=excluded.origin,tax_code_kind=excluded.tax_code_kind,tax_code=excluded.tax_code,icms_rate=excluded.icms_rate,icms_base_percent=excluded.icms_base_percent,ipi_rate=excluded.ipi_rate,gross_weight=excluded.gross_weight,net_weight=excluded.net_weight
  returning item_id into v_id;
  v_result:=jsonb_build_object('status','saved','itemId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_set_item_commercial_data_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'catalog.manage','core.catalog');c:=public.erp_claim_command_v1(p_tenant_id,'catalog.item.commercial.set',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_catalog_items i where i.tenant_id=p_tenant_id and i.id=(p_payload->>'itemId')::uuid)then raise exception using errcode='22023',message='item not found';end if;
  insert into public.erp_item_commercial_data(tenant_id,item_id,cost_price,margin_percent,suggested_sale_price,min_stock_quantity,reorder_point)
  values(p_tenant_id,(p_payload->>'itemId')::uuid,coalesce((p_payload->>'costPrice')::numeric,0),coalesce((p_payload->>'marginPercent')::numeric,0),nullif(p_payload->>'suggestedSalePrice','')::numeric,coalesce((p_payload->>'minStockQuantity')::numeric,0),nullif(p_payload->>'reorderPoint','')::numeric)
  on conflict(tenant_id,item_id) do update set cost_price=excluded.cost_price,margin_percent=excluded.margin_percent,suggested_sale_price=excluded.suggested_sale_price,min_stock_quantity=excluded.min_stock_quantity,reorder_point=excluded.reorder_point
  returning item_id into v_id;
  v_result:=jsonb_build_object('status','saved','itemId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

create or replace function public.erp_command_set_establishment_vertical_v1(p_tenant_id uuid,p_request_id text,p_payload_hash text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c jsonb;v_id uuid;v_result jsonb;
begin
  perform public.erp_require_command_access_v1(p_tenant_id,'establishments.manage','core.organization');c:=public.erp_claim_command_v1(p_tenant_id,'establishment.vertical.set',p_request_id,p_payload_hash,p_payload);if(c->>'replayed')::boolean then return c->'result';end if;
  if not exists(select 1 from public.erp_establishments e where e.tenant_id=p_tenant_id and e.id=(p_payload->>'establishmentId')::uuid)then raise exception using errcode='22023',message='establishment not found';end if;
  if not exists(select 1 from public.erp_business_verticals v where v.code=p_payload->>'verticalCode' and v.active)then raise exception using errcode='22023',message='vertical not found';end if;
  update public.erp_establishments set vertical_code=p_payload->>'verticalCode' where tenant_id=p_tenant_id and id=(p_payload->>'establishmentId')::uuid returning id into v_id;
  v_result:=jsonb_build_object('status','saved','establishmentId',v_id);return public.erp_complete_command_v1(p_tenant_id,(c->>'receiptId')::uuid,v_result);
end$$;

revoke execute on function
  public.erp_command_add_party_document_v1(uuid,text,text,jsonb),
  public.erp_command_add_party_contact_v1(uuid,text,text,jsonb),
  public.erp_command_add_party_address_v1(uuid,text,text,jsonb),
  public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb),
  public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb),
  public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)
from public,anon;
grant execute on function
  public.erp_command_add_party_document_v1(uuid,text,text,jsonb),
  public.erp_command_add_party_contact_v1(uuid,text,text,jsonb),
  public.erp_command_add_party_address_v1(uuid,text,text,jsonb),
  public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb),
  public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb),
  public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)
to authenticated,service_role;

commit;
