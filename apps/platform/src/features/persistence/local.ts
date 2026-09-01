import 'server-only';
import { createVisualPersistenceClient, type Json, type RpcTransport } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import type { Party, PartyKind, PartyRole } from '@/features/parties/types';
import type { CatalogItem, ItemKind, Unit } from '@/features/catalog/types';

const tenantId = '00000000-0000-4000-8000-000000000018';
const unit: Unit = { id: '00000000-0000-4000-8000-000000000001', code: 'UN', name: 'Unidade', dimension: 'count', decimal_scale: 0 };
export type LocalStockRow={itemId:string;code:string;name:string;quantity:number};
export type LocalCashRow={id:string;status:'open'|'closed';openingAmount:number;expectedAmount:number;openedAt:string};
export type LocalSaleRow={id:string;code:string;itemName:string;quantity:number;total:number;paymentKind:'cash'|'store_credit';createdAt:string};
export type LocalReceivable={id:string;code:string;customerName:string;total:number;settled:number;status:'open'|'partially_settled'|'settled'};
type LocalDraft={id:string;idempotencyKey:string;itemId:string;quantity:number;paymentKind:'cash'|'store_credit';customerId?:string;total:number};type SettlementDraft={id:string;idempotencyKey:string;receivableId:string;amount:number};
type LocalReceipt={rpc:string;payloadHash:string;result:Json};
type LocalState = { parties: Party[]; items: CatalogItem[]; prices:Record<string,number>; stock:Record<string,number>; stockMovements:number; cash:LocalCashRow|null; sales:LocalSaleRow[]; drafts:Record<string,LocalDraft>;receivables:LocalReceivable[];settlementDrafts:Record<string,SettlementDraft>;receipts:Record<string,LocalReceipt> };
const globalState = globalThis as typeof globalThis & { __connectionCyberM18G5?: LocalState };
const state = globalState.__connectionCyberM18G5 ??= { parties: [], items: [], prices:{}, stock:{}, stockMovements:0, cash:null, sales:[], drafts:{},receivables:[],settlementDrafts:{},receipts:{} };
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
export async function localDashboard(){const salesTotal=state.sales.reduce((sum,row)=>sum+row.total,0),cashSales=state.sales.filter(row=>row.paymentKind==='cash').reduce((sum,row)=>sum+row.total,0),receivables=state.receivables.reduce((sum,row)=>sum+row.total,0),settled=state.receivables.reduce((sum,row)=>sum+row.settled,0);return{customers:state.parties.filter(row=>row.erp_party_roles.some(role=>role.role==='customer')).length,products:state.items.length,stockUnits:stockRows().reduce((sum,row)=>sum+row.quantity,0),salesCount:state.sales.length,salesTotal,cashSales,receivables,settled,openReceivables:receivables-settled,cashStatus:state.cash?.status??'closed',balanced:salesTotal===cashSales+receivables};}
export async function prepareLocalSale(itemId:string,quantity:number,paymentKind:'cash'|'store_credit',customerId?:string){const item=state.items.find(row=>row.id===itemId);if(!item||quantity<=0||!Number.isInteger(quantity)||paymentKind==='store_credit'&&!customerId)throw new Error('INVALID_INPUT');const id=crypto.randomUUID(),idempotencyKey=`local-sale:${id}`;state.drafts[id]={id,idempotencyKey,itemId,quantity,paymentKind,customerId,total:(state.prices[itemId]??100)*quantity};return{id,idempotencyKey,total:state.drafts[id].total};}
export async function prepareLocalSettlement(receivableId:string,amount:number){const entry=state.receivables.find(row=>row.id===receivableId);if(!entry||amount<=0||amount>entry.total-entry.settled)throw new Error('INVALID_STATE');const id=crypto.randomUUID(),idempotencyKey=`local-settlement:${id}`;state.settlementDrafts[id]={id,idempotencyKey,receivableId,amount};return{id,idempotencyKey};}
export const localPersistenceMode = 'M18-G5 · transporte local auditado · nenhum dado é enviado ao Supabase';
