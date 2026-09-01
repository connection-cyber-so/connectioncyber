import 'server-only';
import { createVisualPersistenceClient, type Json, type RpcTransport } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import type { Party, PartyKind, PartyRole } from '@/features/parties/types';
import type { CatalogItem, ItemKind, Unit } from '@/features/catalog/types';

const tenantId = '00000000-0000-4000-8000-000000000018';
const unit: Unit = { id: '00000000-0000-4000-8000-000000000001', code: 'UN', name: 'Unidade', dimension: 'count', decimal_scale: 0 };
type LocalState = { parties: Party[]; items: CatalogItem[] };
const globalState = globalThis as typeof globalThis & { __connectionCyberM18G2?: LocalState };
const state = globalState.__connectionCyberM18G2 ??= { parties: [], items: [] };
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
      return { status: 'created', itemId: id } as Json;
    }
    throw Object.assign(new Error('command unavailable in M18-G2'), { code: 'CAPABILITY_REQUIRED' });
  },
  async read(contract, requestedTenantId) {
    if (requestedTenantId !== tenantId) throw Object.assign(new Error('tenant mismatch'), { code: 'ACCESS_DENIED' });
    if (contract.source === 'erp_parties') return copy(state.parties) as unknown as Json;
    if (contract.source === 'erp_catalog_items') return copy(state.items) as unknown as Json;
    return [];
  }
};

export const localPersistenceClient = createVisualPersistenceClient({ transport, resolveTenant: async () => tenantId });
export async function listLocalParties() { return copy(state.parties); }
export async function listLocalCatalogItems() { return copy(state.items); }
export async function listLocalUnits() { return [copy(unit)]; }
export const localPersistenceMode = 'M18-G2 · transporte local sintético · nenhum dado é enviado ao Supabase';
