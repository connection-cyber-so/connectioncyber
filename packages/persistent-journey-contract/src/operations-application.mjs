import { fail, payloadHash } from './index.mjs';

const clean = value => typeof value === 'string' ? value.trim().toUpperCase() : '';
const localId = (prefix, tenantId, command) => `${prefix}-${payloadHash({ tenantId, requestId: command.requestId, type: command.type }).slice(0, 20).toUpperCase()}`;
const integer = (value, minimum = 1) => Number.isInteger(value) && value >= minimum;

export class MemoryOperationsStore {
  #catalog; #state = { stock: new Map(), cash: new Map(), sales: new Map(), inbox: new Map(), movements: [] };
  constructor({ catalog }) { if (!catalog?.getItem) fail('CONTEXT_RESOLUTION_FAILED'); this.#catalog = catalog; }
  execute(authorization, command) {
    if (!authorization?.serverResolved || authorization.commandHash !== payloadHash(command)) fail('AUTHORIZATION_CONTEXT_MISMATCH');
    const prior = this.#state.inbox.get(authorization.idempotencyKey);
    if (prior && prior.commandHash !== authorization.commandHash) fail('IDEMPOTENCY_CONFLICT');
    if (prior) return Object.freeze({ ...structuredClone(prior.result), replayed: true });
    const snapshot = structuredClone(this.#state);
    try {
      const handlers = { 'inventory.receive': () => this.#receive(authorization, command), 'cash.open': () => this.#openCash(authorization, command), 'sale.complete': () => this.#completeSale(authorization, command), 'cash.close': () => this.#closeCash(authorization, command) };
      const result = handlers[command.type]?.() ?? fail('INVALID_COMMAND');
      if (command.payload.injectFailure === 'SYNTHETIC-AFTER-OPERATION') fail('INTERNAL_FAILURE');
      const output = Object.freeze({ ...result, replayed: false });
      this.#state.inbox.set(authorization.idempotencyKey, { commandHash: authorization.commandHash, result: output });
      return output;
    } catch (error) { this.#state = snapshot; throw error; }
  }
  #stockMap(tenantId) { if (!this.#state.stock.has(tenantId)) this.#state.stock.set(tenantId, new Map()); return this.#state.stock.get(tenantId); }
  #salesMap(tenantId) { if (!this.#state.sales.has(tenantId)) this.#state.sales.set(tenantId, new Map()); return this.#state.sales.get(tenantId); }
  #receive(authorization, command) {
    const itemCode = clean(command.payload.itemCode), item = this.#catalog.getItem(authorization.tenantId, itemCode);
    if (!item || !item.trackInventory) fail('RESOURCE_NOT_FOUND');
    if (!integer(command.payload.quantity)) fail('INVALID_COMMAND');
    const stock = this.#stockMap(authorization.tenantId), balance = (stock.get(itemCode) ?? 0) + command.payload.quantity;
    stock.set(itemCode, balance); this.#state.movements.push(Object.freeze({ tenantId: authorization.tenantId, itemCode, quantity: command.payload.quantity, kind: 'receipt' }));
    return { status: 'received', itemCode, balance };
  }
  #openCash(authorization, command) {
    if (!integer(command.payload.openingAmountCents, 0)) fail('INVALID_COMMAND');
    const current = this.#state.cash.get(authorization.tenantId);
    if (current?.status === 'open') fail('INVALID_STATE_TRANSITION');
    const cash = Object.freeze({ id: localId('SYNTHETIC-CASH', authorization.tenantId, command), status: 'open', openingAmountCents: command.payload.openingAmountCents, expectedAmountCents: command.payload.openingAmountCents, salesAmountCents: 0 });
    this.#state.cash.set(authorization.tenantId, cash); return { status: 'opened', cash };
  }
  #completeSale(authorization, command) {
    const cash = this.#state.cash.get(authorization.tenantId);
    if (cash?.status !== 'open') fail('CASH_REGISTER_CLOSED');
    if (!Array.isArray(command.payload.lines) || command.payload.lines.length < 1 || !/^SYNTHETIC[ -]/.test(command.payload.saleCode ?? '') || !/^SYNTHETIC[ -]/.test(command.payload.paymentMethod ?? '')) fail('INVALID_COMMAND');
    const stock = this.#stockMap(authorization.tenantId), lines = command.payload.lines.map(line => {
      const itemCode = clean(line.itemCode), item = this.#catalog.getItem(authorization.tenantId, itemCode);
      if (!item || !integer(line.quantity)) fail('RESOURCE_NOT_FOUND');
      if (item.trackInventory && (stock.get(itemCode) ?? 0) < line.quantity) fail('INSUFFICIENT_STOCK');
      return { item, itemCode, quantity: line.quantity, lineTotalCents: item.priceCents * line.quantity };
    });
    const totalCents = lines.reduce((sum, line) => sum + line.lineTotalCents, 0);
    for (const line of lines) if (line.item.trackInventory) { stock.set(line.itemCode, stock.get(line.itemCode) - line.quantity); this.#state.movements.push(Object.freeze({ tenantId: authorization.tenantId, itemCode: line.itemCode, quantity: -line.quantity, kind: 'sale' })); }
    if (command.payload.injectFailure === 'SYNTHETIC-AFTER-STOCK') fail('INTERNAL_FAILURE');
    const paymentKind = command.payload.paymentKind ?? 'cash';
    if (!['cash', 'credit'].includes(paymentKind)) fail('INVALID_COMMAND');
    const sale = Object.freeze({ id: localId('SYNTHETIC-SALE', authorization.tenantId, command), tenantId: authorization.tenantId, code: command.payload.saleCode, totalCents, paymentMethod: command.payload.paymentMethod, paymentKind, lines: Object.freeze(lines.map(line => Object.freeze({ itemCode: line.itemCode, quantity: line.quantity, unitPriceCents: line.item.priceCents, lineTotalCents: line.lineTotalCents }))), createdBy: authorization.actorId });
    this.#salesMap(authorization.tenantId).set(sale.id, sale);
    const cashAmountCents = paymentKind === 'cash' ? totalCents : 0;
    this.#state.cash.set(authorization.tenantId, Object.freeze({ ...cash, expectedAmountCents: cash.expectedAmountCents + cashAmountCents, salesAmountCents: cash.salesAmountCents + cashAmountCents }));
    return { status: 'completed', sale, cashExpectedAmountCents: cash.expectedAmountCents + cashAmountCents };
  }
  #closeCash(authorization, command) {
    const cash = this.#state.cash.get(authorization.tenantId);
    if (cash?.status !== 'open') fail('CASH_REGISTER_CLOSED');
    if (!integer(command.payload.declaredAmountCents, 0)) fail('INVALID_COMMAND');
    if (command.payload.declaredAmountCents !== cash.expectedAmountCents) fail('CASH_DIFFERENCE');
    const closed = Object.freeze({ ...cash, status: 'closed', declaredAmountCents: command.payload.declaredAmountCents }); this.#state.cash.set(authorization.tenantId, closed);
    return { status: 'closed', cash: closed };
  }
  snapshot(tenantId) { if (!/^SYNTHETIC-TENANT-/.test(tenantId ?? '')) fail('TENANT_CONTEXT_REQUIRED'); return Object.freeze({ stock: Object.freeze(Object.fromEntries(this.#state.stock.get(tenantId) ?? [])), cash: this.#state.cash.get(tenantId) ?? null, sales: Object.freeze([...(this.#state.sales.get(tenantId)?.values() ?? [])]), movements: Object.freeze(this.#state.movements.filter(row => row.tenantId === tenantId)) }); }
  evidence() { return Object.freeze({ commands: this.#state.inbox.size, movements: this.#state.movements.length, persisted: false, remoteAccessed: false, productionAccessed: false }); }
}

export function createOperationsApplication({ authorizer, store }) {
  if (!authorizer?.authorize || !store?.execute) fail('CONTEXT_RESOLUTION_FAILED');
  return Object.freeze({ async execute({ host, command }) { const authorization = await authorizer.authorize({ host, command }); return store.execute(authorization, command); } });
}
