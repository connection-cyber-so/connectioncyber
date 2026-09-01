import 'server-only';
import { createVisualPersistenceClient, type Json, type RpcTransport } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import type { Party, PartyKind, PartyRole } from '@/features/parties/types';
import type { CatalogItem, ItemKind, Unit } from '@/features/catalog/types';

const tenantId = '00000000-0000-4000-8000-000000000018';
const unit: Unit = { id: '00000000-0000-4000-8000-000000000001', code: 'UN', name: 'Unidade', dimension: 'count', decimal_scale: 0 };
export type LocalStockRow={itemId:string;code:string;name:string;quantity:number};
export type LocalCashRow={id:string;status:'open'|'closed';openingAmount:number;expectedAmount:number;openedAt:string};
export type LocalSaleRow={id:string;code:string;itemName:string;quantity:number;total:number;paymentKind:'cash'|'store_credit';createdAt:string};
type LocalDraft={id:string;idempotencyKey:string;itemId:string;quantity:number;paymentKind:'cash'|'store_credit';total:number};
type LocalState = { parties: Party[]; items: CatalogItem[]; prices:Record<string,number>; stock:Record<string,number>; stockMovements:number; cash:LocalCashRow|null; sales:LocalSaleRow[]; drafts:Record<string,LocalDraft> };
const globalState = globalThis as typeof globalThis & { __connectionCyberM18G3?: LocalState };
const state = globalState.__connectionCyberM18G3 ??= { parties: [], items: [], prices:{}, stock:{}, stockMovements:0, cash:null, sales:[], drafts:{} };
const copy = <T>(value: T): T => structuredClone(value);

const transport: RpcTransport = {
  async rpc(rpc, args) {
    const payload = args.p_payload;
    if (rpc === 'erp_command_create_party_v1') {
      const taxId = String(payload.taxId ?? '');
      if (taxId && state.parties.some(row => row.tax_id === taxId)) throw Object.assign(new Error('duplicate party'), { code: 'IDEMPOTENCY_CONFLICT' });
      const id = crypto.randomUUID();
      state.parties.push({ id, tenant_id: args.p_tenant_id, kind: payload.kind as PartyKind, legal_name: String(payload.legalName), trade_name: String(payload.tradeName || '') || null, tax_id: taxId || null, active: true, created_at: new Date().toISOString(), erp_party_roles: [{ role: payload.role as PartyRole, active: true }] });
      return { status: 'created', partyId: id } as Json;
    }
    if (rpc === 'erp_command_create_catalog_item_v1') {
      const code = String(payload.code).trim().toUpperCase();
      if (state.items.some(row => row.code === code)) throw Object.assign(new Error('duplicate catalog code'), { code: 'IDEMPOTENCY_CONFLICT' });
      const id = crypto.randomUUID();
      state.items.push({ id, tenant_id: args.p_tenant_id, kind: payload.kind as ItemKind, code, name: String(payload.name), description: String(payload.description || '') || null, track_inventory: Boolean(payload.trackInventory), allows_fraction: Boolean(payload.allowsFraction), status: 'active', erp_units: { code: unit.code, name: unit.name } });
      state.prices[id]=100;state.stock[id]=0;
      return { status: 'created', itemId: id } as Json;
    }
    if(rpc==='erp_command_receive_inventory_v1'){
      const itemId=String(payload.itemId),quantity=Number(payload.quantity),item=state.items.find(row=>row.id===itemId);
      if(!item?.track_inventory||!Number.isFinite(quantity)||quantity<=0)throw Object.assign(new Error('inventory target unavailable'),{code:'INVALID_INPUT'});
      state.stock[itemId]=(state.stock[itemId]??0)+quantity;state.stockMovements+=1;return{status:'received',stockMovementId:crypto.randomUUID()}as Json;
    }
    if(rpc==='erp_command_open_cash_v1'){
      if(state.cash?.status==='open')throw Object.assign(new Error('cash already open'),{code:'INVALID_STATE'});const openingAmount=Number(payload.openingAmount);if(!Number.isFinite(openingAmount)||openingAmount<0)throw Object.assign(new Error('invalid opening'),{code:'INVALID_INPUT'});
      const id=crypto.randomUUID();state.cash={id,status:'open',openingAmount,expectedAmount:openingAmount,openedAt:new Date().toISOString()};return{status:'opened',cashSessionId:id}as Json;
    }
    if(rpc==='erp_command_complete_sale_v1'){
      const draft=state.drafts[String(payload.saleId)];if(!draft||draft.idempotencyKey!==payload.saleIdempotencyKey)throw Object.assign(new Error('sale draft unavailable'),{code:'INVALID_STATE'});
      const item=state.items.find(row=>row.id===draft.itemId);if(!item||draft.quantity>(state.stock[draft.itemId]??0))throw Object.assign(new Error('insufficient stock'),{code:'INVALID_STATE'});if(draft.paymentKind==='cash'&&state.cash?.status!=='open')throw Object.assign(new Error('cash required'),{code:'INVALID_STATE'});
      state.stock[draft.itemId]-=draft.quantity;if(draft.paymentKind==='cash'&&state.cash)state.cash.expectedAmount+=draft.total;state.sales.push({id:draft.id,code:`VEN-${String(state.sales.length+1).padStart(4,'0')}`,itemName:item.name,quantity:draft.quantity,total:draft.total,paymentKind:draft.paymentKind,createdAt:new Date().toISOString()});delete state.drafts[draft.id];return{status:'completed',saleId:draft.id}as Json;
    }
    throw Object.assign(new Error('command unavailable in M18-G3'), { code: 'CAPABILITY_REQUIRED' });
  },
  async read(contract, requestedTenantId) {
    if (requestedTenantId !== tenantId) throw Object.assign(new Error('tenant mismatch'), { code: 'ACCESS_DENIED' });
    if (contract.source === 'erp_parties') return copy(state.parties) as unknown as Json;
    if (contract.source === 'erp_catalog_items') return copy(state.items) as unknown as Json;
    if(contract.source==='erp_stock_balance_v')return copy(stockRows())as unknown as Json;
    if(contract.source==='erp_stock_movements')return{count:state.stockMovements}as Json;
    if(contract.source==='erp_cash_sessions')return copy(state.cash?[state.cash]:[])as unknown as Json;
    if(contract.source==='erp_sales')return copy(state.sales)as unknown as Json;
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
export async function prepareLocalSale(itemId:string,quantity:number,paymentKind:'cash'|'store_credit'){const item=state.items.find(row=>row.id===itemId);if(!item||quantity<=0||!Number.isInteger(quantity))throw new Error('INVALID_INPUT');const id=crypto.randomUUID(),idempotencyKey=`local-sale:${id}`;state.drafts[id]={id,idempotencyKey,itemId,quantity,paymentKind,total:(state.prices[itemId]??100)*quantity};return{id,idempotencyKey,total:state.drafts[id].total};}
export const localPersistenceMode = 'M18-G3 · transporte local sintético · nenhum dado é enviado ao Supabase';
