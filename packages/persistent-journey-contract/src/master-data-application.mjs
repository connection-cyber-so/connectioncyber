import { fail, payloadHash } from './index.mjs';

const PARTY_KINDS = new Set(['person', 'organization']);
const PARTY_ROLES = new Set(['customer', 'supplier', 'employee', 'buyer', 'sales_rep', 'technician', 'carrier', 'other']);
const ITEM_KINDS = new Set(['product', 'service', 'part', 'ingredient', 'prepared', 'kit', 'supply', 'fee', 'voucher']);
const NON_STOCK_KINDS = new Set(['service', 'fee', 'voucher']);
const clean = value => typeof value === 'string' ? value.trim() : '';
const localId = (prefix, tenantId, command) => `${prefix}-${payloadHash({ tenantId, requestId: command.requestId, type: command.type }).slice(0, 20).toUpperCase()}`;

function validateParty(payload) {
  const legalName = clean(payload.legalName), tradeName = clean(payload.tradeName);
  if (!PARTY_KINDS.has(payload.kind) || !PARTY_ROLES.has(payload.role) || !/^SYNTHETIC[ -]/.test(legalName) || (tradeName && !/^SYNTHETIC[ -]/.test(tradeName)) || legalName.length > 180 || tradeName.length > 180) fail('INVALID_COMMAND');
  return { kind: payload.kind, legalName, tradeName: tradeName || null, role: payload.role };
}

function validateItem(payload) {
  const code = clean(payload.code).toUpperCase(), name = clean(payload.name), description = clean(payload.description);
  if (!ITEM_KINDS.has(payload.kind) || !/^SYNTHETIC[-_.][A-Z0-9._-]{1,54}$/.test(code) || !/^SYNTHETIC[ -]/.test(name) || (description && !/^SYNTHETIC[ -]/.test(description)) || name.length > 180 || description.length > 1000 || typeof payload.trackInventory !== 'boolean' || typeof payload.allowsFraction !== 'boolean') fail('INVALID_COMMAND');
  if (NON_STOCK_KINDS.has(payload.kind) && payload.trackInventory) fail('INVALID_COMMAND');
  return { kind: payload.kind, code, name, description: description || null, trackInventory: payload.trackInventory, allowsFraction: payload.allowsFraction };
}

export class MemoryMasterDataStore {
  #state = { parties: new Map(), items: new Map(), inbox: new Map() };
  execute(authorization, command) {
    if (!authorization?.serverResolved || authorization.commandHash !== payloadHash(command)) fail('AUTHORIZATION_CONTEXT_MISMATCH');
    const prior = this.#state.inbox.get(authorization.idempotencyKey);
    if (prior && prior.commandHash !== authorization.commandHash) fail('IDEMPOTENCY_CONFLICT');
    if (prior) return Object.freeze({ ...structuredClone(prior.result), replayed: true });
    const snapshot = structuredClone(this.#state);
    try {
      const result = command.type === 'party.create' ? this.#createParty(authorization, command) : command.type === 'catalog.item.create' ? this.#createItem(authorization, command) : fail('INVALID_COMMAND');
      if (command.payload.injectFailure === 'SYNTHETIC-AFTER-REPOSITORY') fail('INTERNAL_FAILURE');
      const output = Object.freeze({ ...result, replayed: false });
      this.#state.inbox.set(authorization.idempotencyKey, { commandHash: authorization.commandHash, result: output });
      return output;
    } catch (error) { this.#state = snapshot; throw error; }
  }
  #tenantMap(domain, tenantId) { const root = this.#state[domain]; if (!root.has(tenantId)) root.set(tenantId, new Map()); return root.get(tenantId); }
  #createParty(authorization, command) {
    const value = validateParty(command.payload), rows = this.#tenantMap('parties', authorization.tenantId), key = value.legalName.toLocaleLowerCase('pt-BR');
    if (rows.has(key)) fail('DUPLICATE_RESOURCE');
    const record = Object.freeze({ id: localId('SYNTHETIC-PARTY', authorization.tenantId, command), tenantId: authorization.tenantId, ...value, active: true, createdBy: authorization.actorId });
    rows.set(key, record); return { status: 'created', resource: record };
  }
  #createItem(authorization, command) {
    const value = validateItem(command.payload), rows = this.#tenantMap('items', authorization.tenantId);
    if (rows.has(value.code)) fail('DUPLICATE_RESOURCE');
    const record = Object.freeze({ id: localId('SYNTHETIC-ITEM', authorization.tenantId, command), tenantId: authorization.tenantId, ...value, status: 'active', createdBy: authorization.actorId });
    rows.set(value.code, record); return { status: 'created', resource: record };
  }
  listParties(tenantId) { if (!/^SYNTHETIC-TENANT-/.test(tenantId ?? '')) fail('TENANT_CONTEXT_REQUIRED'); return Object.freeze([...(this.#state.parties.get(tenantId)?.values() ?? [])]); }
  listItems(tenantId) { if (!/^SYNTHETIC-TENANT-/.test(tenantId ?? '')) fail('TENANT_CONTEXT_REQUIRED'); return Object.freeze([...(this.#state.items.get(tenantId)?.values() ?? [])]); }
  evidence() { return Object.freeze({ tenantsWithParties: this.#state.parties.size, tenantsWithItems: this.#state.items.size, commands: this.#state.inbox.size, persisted: false, remoteAccessed: false, productionAccessed: false }); }
}

export function createMasterDataApplication({ authorizer, store }) {
  if (!authorizer?.authorize || !store?.execute) fail('CONTEXT_RESOLUTION_FAILED');
  return Object.freeze({ async execute({ host, command }) { const authorization = await authorizer.authorize({ host, command }); return store.execute(authorization, command); } });
}
