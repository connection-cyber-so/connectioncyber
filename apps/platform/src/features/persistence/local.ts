import 'server-only';
import { createVisualPersistenceClient, type Json, type RpcTransport } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import type { Party, PartyAddress, PartyContact, PartyDocument, PartyKind, PartyRole } from '@/features/parties/types';
import type { BusinessVertical, CatalogItem, ItemCommercialData, ItemFiscalData, ItemKind, Unit, VerticalAttributeRequirement } from '@/features/catalog/types';

const tenantId = '00000000-0000-4000-8000-000000000018';
const unit: Unit = { id: '00000000-0000-4000-8000-000000000001', code: 'UN', name: 'Unidade', dimension: 'count', decimal_scale: 0 };

// M20-G2 — catálogo global de verticais/atributos exigidos (mesmo seed da migration
// 0038), fixo aqui porque no transporte sintético não existe leitura real de banco.
export interface LocalEstablishment{id:string;code:string;trade_name:string;vertical_code:string|null;legal_name?:string|null;cnpj?:string|null}
export const BUSINESS_VERTICALS: BusinessVertical[] = [
  { code:'moda', name:'Moda/vestuário', description:'Roupas, acessórios e calçados em geral.', segment_profile_key:'apparel_stationery', active:true },
  { code:'oficina', name:'Oficina (mecânica/CFTV/elétrica/solar)', description:'Manutenção, instalação e reparo com peças e mão de obra.', segment_profile_key:'workshop', active:true },
  { code:'restaurante', name:'Restaurante/alimentação', description:'Preparo e venda de refeições, comandas e produção de cozinha.', segment_profile_key:'food_service', active:true },
  { code:'papelaria', name:'Papelaria', description:'Material de escritório, escolar e afins.', segment_profile_key:'apparel_stationery', active:true },
  { code:'material_construcao', name:'Material de construção', description:'Insumos e materiais para obra e reforma.', segment_profile_key:'retail_general', active:true },
  { code:'celular_multi_cnpj', name:'Celular (venda e reparo, multi-CNPJ)', description:'Venda de aparelhos/acessórios e reparo técnico, tipicamente em mais de um estabelecimento.', segment_profile_key:'workshop', active:true },
  { code:'adega', name:'Adega', description:'Bebidas alcoólicas para revenda.', segment_profile_key:'retail_general', active:true },
  { code:'casa_de_bolos', name:'Casa de bolos (fabricação e venda)', description:'Fabrica e vende — ficha técnica/receita e validade por lote.', segment_profile_key:'food_service', active:true },
  { code:'loja_variedades', name:'Loja de variedades', description:'Bazar e utilidades diversas.', segment_profile_key:'apparel_stationery', active:true },
  { code:'cabeleireiro_barbeiro', name:'Cabeleireiro e barbeiro', description:'Serviços agendados de estética capilar.', segment_profile_key:'professional_services', active:true },
  { code:'perfumaria_cosmetico', name:'Perfumaria e cosmético', description:'Fragrâncias e cosméticos para revenda.', segment_profile_key:'retail_general', active:true },
  { code:'loja_calcados', name:'Loja de calçados', description:'Calçados em geral, com numeração.', segment_profile_key:'apparel_stationery', active:true },
  { code:'servicos_mei_pf', name:'Serviços ME/PF', description:'Prestação de serviço genérica, sem estoque físico obrigatório.', segment_profile_key:'professional_services', active:true },
  { code:'servicos_informatica', name:'Serviços de informática', description:'Suporte técnico, manutenção e venda de periféricos.', segment_profile_key:'professional_services', active:true },
];
export const VERTICAL_ATTRIBUTE_REQUIREMENTS: VerticalAttributeRequirement[] = [
  { vertical_code:'moda', attribute_code:'tamanho', attribute_name:'Tamanho', data_type:'option', required:true, sort_order:1 },
  { vertical_code:'moda', attribute_code:'cor', attribute_name:'Cor', data_type:'option', required:true, sort_order:2 },
  { vertical_code:'oficina', attribute_code:'garantia_dias', attribute_name:'Garantia (dias)', data_type:'number', required:false, sort_order:1 },
  { vertical_code:'restaurante', attribute_code:'tempo_preparo_min', attribute_name:'Tempo de preparo (min)', data_type:'number', required:false, sort_order:1 },
  { vertical_code:'material_construcao', attribute_code:'medida_padrao', attribute_name:'Medida padrão de venda', data_type:'text', required:false, sort_order:1 },
  { vertical_code:'celular_multi_cnpj', attribute_code:'imei_obrigatorio', attribute_name:'Exige IMEI', data_type:'boolean', required:true, sort_order:1 },
  { vertical_code:'adega', attribute_code:'teor_alcoolico', attribute_name:'Teor alcoólico (%)', data_type:'number', required:true, sort_order:1 },
  { vertical_code:'adega', attribute_code:'volume_ml', attribute_name:'Volume (ml)', data_type:'number', required:false, sort_order:2 },
  { vertical_code:'casa_de_bolos', attribute_code:'validade_dias', attribute_name:'Validade padrão (dias após fabricação)', data_type:'number', required:true, sort_order:1 },
  { vertical_code:'cabeleireiro_barbeiro', attribute_code:'duracao_min', attribute_name:'Duração do serviço (min)', data_type:'number', required:true, sort_order:1 },
  { vertical_code:'perfumaria_cosmetico', attribute_code:'registro_anvisa', attribute_name:'Registro ANVISA', data_type:'text', required:false, sort_order:1 },
  { vertical_code:'loja_calcados', attribute_code:'numeracao', attribute_name:'Numeração', data_type:'option', required:true, sort_order:1 },
  { vertical_code:'servicos_informatica', attribute_code:'garantia_dias', attribute_name:'Garantia (dias)', data_type:'number', required:false, sort_order:1 },
];
export type LocalStockRow={itemId:string;code:string;name:string;quantity:number};
export type LocalCashRow={id:string;status:'open'|'closed';openingAmount:number;expectedAmount:number;openedAt:string};
export type LocalSaleRow={id:string;code:string;itemName:string;quantity:number;total:number;paymentKind:'cash'|'store_credit';createdAt:string};
export type LocalReceivable={id:string;code:string;customerName:string;total:number;settled:number;status:'open'|'partially_settled'|'settled'};
type LocalDraft={id:string;idempotencyKey:string;itemId:string;quantity:number;paymentKind:'cash'|'store_credit';customerId?:string;total:number};type SettlementDraft={id:string;idempotencyKey:string;receivableId:string;amount:number};
type LocalReceipt={rpc:string;payloadHash:string;result:Json};
type LocalState = { parties: Party[]; items: CatalogItem[]; prices:Record<string,number>; stock:Record<string,number>; stockMovements:number; cash:LocalCashRow|null; sales:LocalSaleRow[]; drafts:Record<string,LocalDraft>;receivables:LocalReceivable[];settlementDrafts:Record<string,SettlementDraft>;receipts:Record<string,LocalReceipt>;
  // M20-G3
  partyDocuments:PartyDocument[]; partyContacts:PartyContact[]; partyAddresses:PartyAddress[];
  itemFiscal:Record<string,ItemFiscalData>; itemCommercial:Record<string,ItemCommercialData>;
  // M20-G4
  establishments:LocalEstablishment[];
};
const globalState = globalThis as typeof globalThis & { __connectionCyberM18G5?: LocalState };
const state = globalState.__connectionCyberM18G5 ??= { parties: [], items: [], prices:{}, stock:{}, stockMovements:0, cash:null, sales:[], drafts:{},receivables:[],settlementDrafts:{},receipts:{},
  partyDocuments:[], partyContacts:[], partyAddresses:[], itemFiscal:{}, itemCommercial:{},
  establishments:[
    { id:'00000000-0000-4000-8000-000000000101', code:'HQ', trade_name:'Loja Centro (matriz)', vertical_code:'moda' },
    { id:'00000000-0000-4000-8000-000000000102', code:'FILIAL-01', trade_name:'Loja Bairro (filial)', vertical_code:'moda' },
  ],
};
const copy = <T>(value: T): T => structuredClone(value);

const transport: RpcTransport = {
  async rpc(rpc, args) {
    if(args.p_tenant_id!==tenantId)throw Object.assign(new Error('tenant mismatch'),{code:'ACCESS_DENIED'});
    const prior=state.receipts[args.p_request_id];
    if(prior){if(prior.rpc!==rpc||prior.payloadHash!==args.p_payload_hash)throw Object.assign(new Error('request replay conflict'),{code:'IDEMPOTENCY_CONFLICT'});return copy(prior.result);}
    const finish=(result:Json)=>{state.receipts[args.p_request_id]={rpc,payloadHash:args.p_payload_hash,result:copy(result)};return result;};
    const payload = args.p_payload;
    if (rpc === 'erp_command_create_party_v1') {
      const taxId = String(payload.taxId ?? '');
      if (taxId && state.parties.some(row => row.tax_id === taxId)) throw Object.assign(new Error('duplicate party'), { code: 'IDEMPOTENCY_CONFLICT' });
      const id = crypto.randomUUID();
      state.parties.push({ id, tenant_id: args.p_tenant_id, kind: payload.kind as PartyKind, legal_name: String(payload.legalName), trade_name: String(payload.tradeName || '') || null, tax_id: taxId || null, active: true, created_at: new Date().toISOString(), erp_party_roles: [{ role: payload.role as PartyRole, active: true }] });
      return finish({ status: 'created', partyId: id } as Json);
    }
    if (rpc === 'erp_command_create_catalog_item_v1') {
      const code = String(payload.code).trim().toUpperCase();
      if (state.items.some(row => row.code === code)) throw Object.assign(new Error('duplicate catalog code'), { code: 'IDEMPOTENCY_CONFLICT' });
      const id = crypto.randomUUID();
      state.items.push({ id, tenant_id: args.p_tenant_id, kind: payload.kind as ItemKind, code, name: String(payload.name), description: String(payload.description || '') || null, track_inventory: Boolean(payload.trackInventory), allows_fraction: Boolean(payload.allowsFraction), status: 'active', erp_units: { code: unit.code, name: unit.name } });
      state.prices[id]=100;state.stock[id]=0;
      return finish({ status: 'created', itemId: id } as Json);
    }
    if(rpc==='erp_command_receive_inventory_v1'){
      const itemId=String(payload.itemId),quantity=Number(payload.quantity),item=state.items.find(row=>row.id===itemId);
      if(!item?.track_inventory||!Number.isFinite(quantity)||quantity<=0)throw Object.assign(new Error('inventory target unavailable'),{code:'INVALID_INPUT'});
      state.stock[itemId]=(state.stock[itemId]??0)+quantity;state.stockMovements+=1;return finish({status:'received',stockMovementId:crypto.randomUUID()}as Json);
    }
    if(rpc==='erp_command_open_cash_v1'){
      if(state.cash?.status==='open')throw Object.assign(new Error('cash already open'),{code:'INVALID_STATE'});const openingAmount=Number(payload.openingAmount);if(!Number.isFinite(openingAmount)||openingAmount<0)throw Object.assign(new Error('invalid opening'),{code:'INVALID_INPUT'});
      const id=crypto.randomUUID();state.cash={id,status:'open',openingAmount,expectedAmount:openingAmount,openedAt:new Date().toISOString()};return finish({status:'opened',cashSessionId:id}as Json);
    }
    if(rpc==='erp_command_complete_sale_v1'){
      const draft=state.drafts[String(payload.saleId)];if(!draft||draft.idempotencyKey!==payload.saleIdempotencyKey)throw Object.assign(new Error('sale draft unavailable'),{code:'INVALID_STATE'});
      const item=state.items.find(row=>row.id===draft.itemId);if(!item||draft.quantity>(state.stock[draft.itemId]??0))throw Object.assign(new Error('insufficient stock'),{code:'INVALID_STATE'});if(draft.paymentKind==='cash'&&state.cash?.status!=='open')throw Object.assign(new Error('cash required'),{code:'INVALID_STATE'});
      const customer=draft.paymentKind==='store_credit'?state.parties.find(row=>row.id===draft.customerId):undefined;if(draft.paymentKind==='store_credit'&&!customer)throw Object.assign(new Error('customer required'),{code:'INVALID_INPUT'});state.stock[draft.itemId]-=draft.quantity;if(draft.paymentKind==='cash'&&state.cash)state.cash.expectedAmount+=draft.total;state.sales.push({id:draft.id,code:`VEN-${String(state.sales.length+1).padStart(4,'0')}`,itemName:item.name,quantity:draft.quantity,total:draft.total,paymentKind:draft.paymentKind,createdAt:new Date().toISOString()});if(customer)state.receivables.push({id:crypto.randomUUID(),code:`REC-${String(state.receivables.length+1).padStart(4,'0')}`,customerName:customer.legal_name,total:draft.total,settled:0,status:'open'});delete state.drafts[draft.id];return finish({status:'completed',saleId:draft.id}as Json);
    }
    if(rpc==='erp_command_settle_receivable_v1'){const draft=state.settlementDrafts[String(payload.settlementId)];if(!draft||draft.idempotencyKey!==payload.settlementIdempotencyKey)throw Object.assign(new Error('settlement unavailable'),{code:'INVALID_STATE'});const entry=state.receivables.find(row=>row.id===draft.receivableId);if(!entry||draft.amount>entry.total-entry.settled)throw Object.assign(new Error('receivable overpayment'),{code:'INVALID_STATE'});entry.settled+=draft.amount;entry.status=entry.settled===entry.total?'settled':'partially_settled';delete state.settlementDrafts[draft.id];return finish({status:'settled',settlementId:draft.id}as Json);}
    if(rpc==='erp_command_close_cash_v1'){if(state.cash?.status!=='open'||String(payload.cashSessionId)!==state.cash.id)throw Object.assign(new Error('cash session unavailable'),{code:'INVALID_STATE'});const counted=Number(payload.countedAmount);if(counted!==state.cash.expectedAmount)throw Object.assign(new Error('cash difference'),{code:'INVALID_STATE'});state.cash.status='closed';return finish({status:'closed',cashSessionId:state.cash.id,expectedAmount:state.cash.expectedAmount}as Json);}
    // M20-G3 — documento/contato/endereço são sempre anexados a uma pessoa já existente.
    if(rpc==='erp_command_add_party_document_v1'){
      const partyId=String(payload.partyId);if(!state.parties.some(row=>row.id===partyId))throw Object.assign(new Error('party not found'),{code:'INVALID_INPUT'});
      const id=crypto.randomUUID();state.partyDocuments.push({id,party_id:partyId,type:payload.type as PartyDocument['type'],number:String(payload.number),issuer:String(payload.issuer||'')||null,issued_at:String(payload.issuedAt||'')||null,expires_at:String(payload.expiresAt||'')||null});
      return finish({status:'created',documentId:id}as Json);
    }
    if(rpc==='erp_command_add_party_contact_v1'){
      const partyId=String(payload.partyId);if(!state.parties.some(row=>row.id===partyId))throw Object.assign(new Error('party not found'),{code:'INVALID_INPUT'});
      const id=crypto.randomUUID();state.partyContacts.push({id,party_id:partyId,type:payload.type as PartyContact['type'],value:String(payload.value),label:String(payload.label||'')||null,is_primary:Boolean(payload.isPrimary)});
      return finish({status:'created',contactId:id}as Json);
    }
    if(rpc==='erp_command_add_party_address_v1'){
      const partyId=String(payload.partyId);if(!state.parties.some(row=>row.id===partyId))throw Object.assign(new Error('party not found'),{code:'INVALID_INPUT'});
      const id=crypto.randomUUID();state.partyAddresses.push({id,party_id:partyId,type:payload.type as PartyAddress['type'],postal_code:String(payload.postalCode||'')||null,street:String(payload.street),number:String(payload.number||'')||null,complement:String(payload.complement||'')||null,district:String(payload.district||'')||null,city:String(payload.city),state_code:String(payload.stateCode||'')||null,country_code:'BR',is_primary:Boolean(payload.isPrimary)});
      return finish({status:'created',addressId:id}as Json);
    }
    // M20-G1/G3 — fiscal/comercial são "set" (upsert 1:1 por item), não "add".
    if(rpc==='erp_command_set_item_fiscal_data_v1'){
      const itemId=String(payload.itemId),item=state.items.find(row=>row.id===itemId);if(!item)throw Object.assign(new Error('item not found'),{code:'INVALID_INPUT'});
      state.itemFiscal[itemId]={item_id:itemId,ncm:String(payload.ncm),cest:String(payload.cest||'')||null,origin:Number(payload.origin??0),tax_code_kind:payload.taxCodeKind as ItemFiscalData['tax_code_kind'],tax_code:String(payload.taxCode),icms_rate:Number(payload.icmsRate??0),icms_base_percent:Number(payload.icmsBasePercent??100),ipi_rate:Number(payload.ipiRate??0),cst_pis:null,cst_cofins:null,fcp_rate:0,gross_weight:payload.grossWeight==null?null:Number(payload.grossWeight),net_weight:payload.netWeight==null?null:Number(payload.netWeight),anp_code:null};
      return finish({status:'set',itemId}as Json);
    }
    if(rpc==='erp_command_set_item_commercial_data_v1'){
      const itemId=String(payload.itemId),item=state.items.find(row=>row.id===itemId);if(!item)throw Object.assign(new Error('item not found'),{code:'INVALID_INPUT'});
      state.itemCommercial[itemId]={item_id:itemId,cost_price:Number(payload.costPrice??0),margin_percent:Number(payload.marginPercent??0),suggested_sale_price:payload.suggestedSalePrice==null?null:Number(payload.suggestedSalePrice),min_stock_quantity:Number(payload.minStockQuantity??0),reorder_point:payload.reorderPoint==null?null:Number(payload.reorderPoint),reorder_quantity:null};
      return finish({status:'set',itemId}as Json);
    }
    // M20-G4 — vertical do estabelecimento (catálogo de verticais é fixo, ver BUSINESS_VERTICALS).
    if(rpc==='erp_command_set_establishment_vertical_v1'){
      const establishmentId=String(payload.establishmentId),establishment=state.establishments.find(row=>row.id===establishmentId);if(!establishment)throw Object.assign(new Error('establishment not found'),{code:'INVALID_INPUT'});
      const verticalCode=String(payload.verticalCode);if(!BUSINESS_VERTICALS.some(row=>row.code===verticalCode))throw Object.assign(new Error('vertical not found'),{code:'INVALID_INPUT'});
      establishment.vertical_code=verticalCode;return finish({status:'set',establishmentId}as Json);
    }
    throw Object.assign(new Error('command unavailable in M18-G5'), { code: 'CAPABILITY_REQUIRED' });
  },
  async read(contract, requestedTenantId) {
    if (requestedTenantId !== tenantId) throw Object.assign(new Error('tenant mismatch'), { code: 'ACCESS_DENIED' });
    if (contract.source === 'erp_parties') return copy(state.parties) as unknown as Json;
    if (contract.source === 'erp_catalog_items') return copy(state.items) as unknown as Json;
    if(contract.source==='erp_stock_balance_v')return copy(stockRows())as unknown as Json;
    if(contract.source==='erp_stock_movements')return{count:state.stockMovements}as Json;
    if(contract.source==='erp_cash_sessions')return copy(state.cash?[state.cash]:[])as unknown as Json;
    if(contract.source==='erp_sales')return copy(state.sales)as unknown as Json;
    if(contract.source==='erp_financial_entries'||contract.source==='erp_installments')return copy(state.receivables)as unknown as Json;
    if(contract.source==='server-aggregate')return{salesTotal:state.sales.reduce((sum,row)=>sum+row.total,0),cashExpected:state.cash?.expectedAmount??0}as Json;
    if(contract.source==='erp_party_documents')return copy(state.partyDocuments)as unknown as Json;
    if(contract.source==='erp_party_contacts')return copy(state.partyContacts)as unknown as Json;
    if(contract.source==='erp_party_addresses')return copy(state.partyAddresses)as unknown as Json;
    if(contract.source==='erp_item_fiscal_data')return copy(Object.values(state.itemFiscal))as unknown as Json;
    if(contract.source==='erp_item_commercial_data')return copy(Object.values(state.itemCommercial))as unknown as Json;
    if(contract.source==='erp_business_verticals')return copy(BUSINESS_VERTICALS)as unknown as Json;
    if(contract.source==='erp_vertical_attribute_requirements')return copy(VERTICAL_ATTRIBUTE_REQUIREMENTS)as unknown as Json;
    if(contract.source==='erp_establishments')return copy(state.establishments)as unknown as Json;
    return [];
  }
};

export const localPersistenceClient = createVisualPersistenceClient({ transport, resolveTenant: async () => tenantId });
export async function listLocalParties() { return copy(state.parties); }
export async function listLocalCatalogItems() { return copy(state.items); }
export async function listLocalUnits() { return [copy(unit)]; }
const stockRows=():LocalStockRow[]=>state.items.filter(item=>item.track_inventory).map(item=>({itemId:item.id,code:item.code,name:item.name,quantity:state.stock[item.id]??0}));
export async function listLocalStock(){return copy(stockRows());}
export async function listLocalCash(){return copy(state.cash);}
export async function listLocalSales(){return copy(state.sales);}
export async function listLocalReceivables(){return copy(state.receivables);}
export async function listLocalPartyDocuments(){return copy(state.partyDocuments);}
export async function listLocalPartyContacts(){return copy(state.partyContacts);}
export async function listLocalPartyAddresses(){return copy(state.partyAddresses);}
export async function listLocalItemFiscalData(){return copy(Object.values(state.itemFiscal));}
export async function listLocalItemCommercialData(){return copy(Object.values(state.itemCommercial));}
export async function listLocalBusinessVerticals(){return copy(BUSINESS_VERTICALS);}
export async function listLocalVerticalAttributeRequirements(){return copy(VERTICAL_ATTRIBUTE_REQUIREMENTS);}
export async function listLocalEstablishments(){return copy(state.establishments);}
export async function localDashboard(){const salesTotal=state.sales.reduce((sum,row)=>sum+row.total,0),cashSales=state.sales.filter(row=>row.paymentKind==='cash').reduce((sum,row)=>sum+row.total,0),receivables=state.receivables.reduce((sum,row)=>sum+row.total,0),settled=state.receivables.reduce((sum,row)=>sum+row.settled,0);return{customers:state.parties.filter(row=>row.erp_party_roles.some(role=>role.role==='customer')).length,products:state.items.length,stockUnits:stockRows().reduce((sum,row)=>sum+row.quantity,0),salesCount:state.sales.length,salesTotal,cashSales,receivables,settled,openReceivables:receivables-settled,cashStatus:state.cash?.status??'closed',balanced:salesTotal===cashSales+receivables};}
export async function prepareLocalSale(itemId:string,quantity:number,paymentKind:'cash'|'store_credit',customerId?:string){const item=state.items.find(row=>row.id===itemId);if(!item||quantity<=0||!Number.isInteger(quantity)||paymentKind==='store_credit'&&!customerId)throw new Error('INVALID_INPUT');const id=crypto.randomUUID(),idempotencyKey=`local-sale:${id}`;state.drafts[id]={id,idempotencyKey,itemId,quantity,paymentKind,customerId,total:(state.prices[itemId]??100)*quantity};return{id,idempotencyKey,total:state.drafts[id].total};}
export async function prepareLocalSettlement(receivableId:string,amount:number){const entry=state.receivables.find(row=>row.id===receivableId);if(!entry||amount<=0||amount>entry.total-entry.settled)throw new Error('INVALID_STATE');const id=crypto.randomUUID(),idempotencyKey=`local-settlement:${id}`;state.settlementDrafts[id]={id,idempotencyKey,receivableId,amount};return{id,idempotencyKey};}
export const localPersistenceMode = 'M18-G5 · transporte local auditado · nenhum dado é enviado ao Supabase';
