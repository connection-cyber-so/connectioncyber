import { createHash } from 'node:crypto';

export const CONTRACT_VERSION = '1.0';
export const COMMANDS = Object.freeze([
  'party.create', 'catalog.item.create', 'inventory.receive', 'cash.open',
  'sale.complete', 'finance.receivable.settle', 'cash.close',
]);
export const AGGREGATE_STATES = Object.freeze({
  party: ['absent', 'active', 'blocked'],
  catalogItem: ['absent', 'active', 'inactive'],
  inventory: ['empty', 'available', 'reserved', 'depleted'],
  cash: ['closed', 'open', 'closing', 'closed_with_difference'],
  sale: ['draft', 'priced', 'reserved', 'completed', 'cancelled'],
  receivable: ['absent', 'open', 'settled', 'reversed'],
});
export const ERROR_CATALOG = Object.freeze({
  SESSION_REQUIRED: { publicCode: 'AUTHENTICATION_REQUIRED', retryable: false, httpStatus: 401 },
  TENANT_NOT_FOUND: { publicCode: 'ACCESS_DENIED', retryable: false, httpStatus: 403 },
  TENANT_HOST_MISMATCH: { publicCode: 'ACCESS_DENIED', retryable: false, httpStatus: 403 },
  MFA_REQUIRED: { publicCode: 'MFA_REQUIRED', retryable: false, httpStatus: 403 },
  PERMISSION_REQUIRED: { publicCode: 'ACCESS_DENIED', retryable: false, httpStatus: 403 },
  CONTEXT_RESOLUTION_FAILED: { publicCode: 'OPERATION_FAILED', retryable: true, httpStatus: 503 },
  INVALID_COMMAND: { publicCode: 'INVALID_REQUEST', retryable: false, httpStatus: 400 },
  AUTHORITY_FIELD_FORBIDDEN: { publicCode: 'INVALID_REQUEST', retryable: false, httpStatus: 400 },
  TENANT_CONTEXT_REQUIRED: { publicCode: 'ACCESS_DENIED', retryable: false, httpStatus: 403 },
  MEMBERSHIP_REQUIRED: { publicCode: 'ACCESS_DENIED', retryable: false, httpStatus: 403 },
  CAPABILITY_REQUIRED: { publicCode: 'CAPABILITY_BLOCKED', retryable: false, httpStatus: 403 },
  INVALID_STATE_TRANSITION: { publicCode: 'OPERATION_NOT_ALLOWED', retryable: false, httpStatus: 409 },
  IDEMPOTENCY_CONFLICT: { publicCode: 'REQUEST_CONFLICT', retryable: false, httpStatus: 409 },
  DUPLICATE_RESOURCE: { publicCode: 'RESOURCE_ALREADY_EXISTS', retryable: false, httpStatus: 409 },
  AUTHORIZATION_CONTEXT_MISMATCH: { publicCode: 'ACCESS_DENIED', retryable: false, httpStatus: 403 },
  INSUFFICIENT_STOCK: { publicCode: 'INSUFFICIENT_STOCK', retryable: false, httpStatus: 409 },
  CASH_REGISTER_CLOSED: { publicCode: 'CASH_REGISTER_CLOSED', retryable: false, httpStatus: 409 },
  CASH_DIFFERENCE: { publicCode: 'CASH_DIFFERENCE', retryable: false, httpStatus: 409 },
  RESOURCE_NOT_FOUND: { publicCode: 'RESOURCE_NOT_FOUND', retryable: false, httpStatus: 404 },
  CONCURRENT_MODIFICATION: { publicCode: 'RETRY_LATER', retryable: true, httpStatus: 409 },
  INTERNAL_FAILURE: { publicCode: 'OPERATION_FAILED', retryable: true, httpStatus: 500 },
});

const AUTHORITY_FIELDS = new Set(['tenantId', 'tenant_id', 'userId', 'actorId', 'actorRole', 'roles', 'capabilities', 'priceTotal', 'stockBalance', 'cashBalance']);
export const fail = (code) => { const definition = ERROR_CATALOG[code] ?? ERROR_CATALOG.INTERNAL_FAILURE; throw Object.assign(new Error(code), { code, publicError: definition }); };
const canonical = (value) => value && typeof value === 'object' ? Array.isArray(value) ? value.map(canonical) : Object.fromEntries(Object.keys(value).sort().map(key => [key, canonical(value[key])])) : value;
export const payloadHash = (value) => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
const walk = (value, visit) => { if (!value || typeof value !== 'object') return; for (const [key, nested] of Object.entries(value)) { visit(key, nested); walk(nested, visit); } };

export function validateServerContext(context) {
  if (!context || !/^SYNTHETIC-TENANT-/.test(context.tenantId ?? '')) fail('TENANT_CONTEXT_REQUIRED');
  if (!/^SYNTHETIC-ACTOR-/.test(context.actorId ?? '') || context.membershipActive !== true) fail('MEMBERSHIP_REQUIRED');
  if (!Array.isArray(context.capabilities)) fail('CAPABILITY_REQUIRED');
  return Object.freeze({ ...context, serverResolved: true });
}

export function validateCommand(command, context) {
  const server = validateServerContext(context);
  if (!command || command.contractVersion !== CONTRACT_VERSION || !COMMANDS.includes(command.type)) fail('INVALID_COMMAND');
  if (!/^SYNTHETIC-REQUEST-[A-Z0-9-]{3,80}$/.test(command.requestId ?? '')) fail('INVALID_COMMAND');
  if (!command.payload || typeof command.payload !== 'object' || Array.isArray(command.payload)) fail('INVALID_COMMAND');
  let forbidden = false;
  walk(command, (key) => { if (AUTHORITY_FIELDS.has(key)) forbidden = true; });
  if (Object.hasOwn(command, 'role')) forbidden = true;
  if (forbidden) fail('AUTHORITY_FIELD_FORBIDDEN');
  const serialized = JSON.stringify(command.payload);
  if (!serialized.includes('SYNTHETIC') || /cnpj|cpf|password|secret|token|certificate|csc|pfx/i.test(serialized)) fail('INVALID_COMMAND');
  if (command.type === 'inventory.receive' && (!Number.isInteger(command.payload.quantity) || command.payload.quantity <= 0)) fail('INVALID_COMMAND');
  if (command.type === 'sale.complete') { const direct = Number.isInteger(command.payload.quantity) && command.payload.quantity > 0, lines = Array.isArray(command.payload.lines) && command.payload.lines.length > 0 && command.payload.lines.every(line => Number.isInteger(line?.quantity) && line.quantity > 0); if (!direct && !lines) fail('INVALID_COMMAND'); }
  if ((command.type === 'sale.complete' || command.type === 'finance.receivable.settle') && (!Number.isInteger(command.payload.amountCents) || command.payload.amountCents <= 0)) fail('INVALID_COMMAND');
  const requiredCapability = command.type.split('.')[0] === 'party' ? 'core.parties' : command.type.startsWith('catalog.') ? 'core.catalog' : command.type.startsWith('inventory.') ? 'inventory.stock' : command.type.startsWith('cash.') || command.type.startsWith('sale.') ? 'sales.pos' : 'finance';
  if (!server.capabilities.includes(requiredCapability)) fail('CAPABILITY_REQUIRED');
  const idempotencyKey = `m17:v1:${server.tenantId}:${command.type}:${command.requestId}`;
  return Object.freeze({ command: Object.freeze(canonical(command)), context: server, idempotencyKey, hash: payloadHash(command) });
}

export function transition(aggregate, current, next) {
  const allowed = {
    party: { absent: ['active'], active: ['blocked'], blocked: ['active'] },
    catalogItem: { absent: ['active'], active: ['inactive'], inactive: ['active'] },
    inventory: { empty: ['available'], available: ['reserved', 'depleted'], reserved: ['available', 'depleted'], depleted: ['available'] },
    cash: { closed: ['open'], open: ['closing'], closing: ['closed', 'closed_with_difference'], closed_with_difference: ['closed'] },
    sale: { draft: ['priced', 'cancelled'], priced: ['reserved', 'cancelled'], reserved: ['completed', 'cancelled'], completed: [], cancelled: [] },
    receivable: { absent: ['open'], open: ['settled'], settled: ['reversed'], reversed: ['open'] },
  };
  if (!allowed[aggregate]?.[current]?.includes(next)) fail('INVALID_STATE_TRANSITION');
  return next;
}

export class MemoryJourneySimulator {
  #records = new Map(); #state = { parties: 0, items: 0, stock: 0, cash: 'closed', sales: 0, receivables: 0, settled: 0 }; #events = [];
  execute(context, command) {
    const validated = validateCommand(command, context), prior = this.#records.get(validated.idempotencyKey);
    if (prior && prior.hash !== validated.hash) fail('IDEMPOTENCY_CONFLICT');
    if (prior) return Object.freeze({ ...prior.result, replayed: true });
    const snapshot = structuredClone(this.#state), eventCount = this.#events.length;
    try {
      const result = this.#apply(command);
      if (command.payload.injectFailure === 'SYNTHETIC-AFTER-APPLY') fail('INTERNAL_FAILURE');
      const output = Object.freeze({ ...result, replayed: false, idempotencyKey: validated.idempotencyKey });
      this.#records.set(validated.idempotencyKey, { hash: validated.hash, result: output });
      this.#events.push(Object.freeze({ tenantId: context.tenantId, actorId: context.actorId, type: command.type, requestId: command.requestId, outcome: 'succeeded', payloadHash: validated.hash }));
      return output;
    } catch (error) { this.#state = snapshot; this.#events.length = eventCount; throw error; }
  }
  #apply(command) {
    switch (command.type) {
      case 'party.create': this.#state.parties += 1; break;
      case 'catalog.item.create': this.#state.items += 1; break;
      case 'inventory.receive': if (this.#state.items < 1) fail('RESOURCE_NOT_FOUND'); this.#state.stock += command.payload.quantity; break;
      case 'cash.open': this.#state.cash = transition('cash', this.#state.cash, 'open'); break;
      case 'sale.complete': if (this.#state.cash !== 'open' || this.#state.stock < command.payload.quantity) fail('INVALID_STATE_TRANSITION'); this.#state.stock -= command.payload.quantity; this.#state.sales += 1; this.#state.receivables += command.payload.amountCents; break;
      case 'finance.receivable.settle': if (this.#state.receivables - this.#state.settled < command.payload.amountCents) fail('INVALID_STATE_TRANSITION'); this.#state.settled += command.payload.amountCents; break;
      case 'cash.close': this.#state.cash = transition('cash', transition('cash', this.#state.cash, 'closing'), 'closed'); break;
      default: fail('INVALID_COMMAND');
    }
    return Object.freeze({ status: 'succeeded', state: structuredClone(this.#state) });
  }
  evidence() { return Object.freeze({ state: structuredClone(this.#state), events: this.#events.length, records: this.#records.size, persisted: false, remoteAccessed: false, productionAccessed: false }); }
}

export function syntheticContext() { return { tenantId: 'SYNTHETIC-TENANT-ME-001', actorId: 'SYNTHETIC-ACTOR-OWNER-001', membershipActive: true, capabilities: ['core.parties', 'core.catalog', 'inventory.stock', 'sales.pos', 'finance'] }; }
export function syntheticCommand(type, sequence, payload) { return { contractVersion: CONTRACT_VERSION, type, requestId: `SYNTHETIC-REQUEST-${String(sequence).padStart(3, '0')}`, payload }; }
