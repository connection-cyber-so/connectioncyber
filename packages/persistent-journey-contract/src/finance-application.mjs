import { fail, payloadHash } from './index.mjs';

const syntheticTenant = tenantId => /^SYNTHETIC-TENANT-/.test(tenantId ?? '');

export class MemoryFinanceStore {
  #operations;
  #state = { entries: new Map(), inbox: new Map(), events: [] };
  constructor({ operations }) { if (!operations?.snapshot) fail('CONTEXT_RESOLUTION_FAILED'); this.#operations = operations; }
  #tenantEntries(tenantId) { if (!this.#state.entries.has(tenantId)) this.#state.entries.set(tenantId, new Map()); return this.#state.entries.get(tenantId); }
  reconcile(tenantId) {
    if (!syntheticTenant(tenantId)) fail('TENANT_CONTEXT_REQUIRED');
    const operational = this.#operations.snapshot(tenantId), entries = new Map(this.#tenantEntries(tenantId));
    for (const sale of operational.sales) {
      const expected = sale.paymentKind === 'credit'
        ? { kind: 'receivable', settledCents: 0, status: 'open' }
        : { kind: 'cash', settledCents: sale.totalCents, status: 'settled' };
      const current = entries.get(sale.id);
      if (!current) entries.set(sale.id, Object.freeze({ tenantId, saleId: sale.id, amountCents: sale.totalCents, ...expected }));
      else if (current.amountCents !== sale.totalCents || current.kind !== expected.kind) fail('RECONCILIATION_MISMATCH');
    }
    for (const entry of entries.values()) if (!operational.sales.some(sale => sale.id === entry.saleId)) fail('RECONCILIATION_MISMATCH');
    this.#state.entries.set(tenantId, entries);
    const rows = [...entries.values()], sum = selector => rows.reduce((total, row) => total + selector(row), 0);
    const grossSalesCents = operational.sales.reduce((total, sale) => total + sale.totalCents, 0);
    const cashSalesCents = sum(row => row.kind === 'cash' ? row.amountCents : 0);
    const receivablesCents = sum(row => row.kind === 'receivable' ? row.amountCents : 0);
    const settledReceivablesCents = sum(row => row.kind === 'receivable' ? row.settledCents : 0);
    const cashRecordedCents = operational.cash?.salesAmountCents ?? 0;
    return Object.freeze({ tenantId, grossSalesCents, cashSalesCents, cashRecordedCents, receivablesCents, settledReceivablesCents, openReceivablesCents: receivablesCents - settledReceivablesCents, balanced: grossSalesCents === cashSalesCents + receivablesCents && cashRecordedCents === cashSalesCents });
  }
  execute(authorization, command) {
    if (!authorization?.serverResolved || authorization.commandHash !== payloadHash(command)) fail('AUTHORIZATION_CONTEXT_MISMATCH');
    if (command.type !== 'finance.receivable.settle') fail('INVALID_COMMAND');
    const prior = this.#state.inbox.get(authorization.idempotencyKey);
    if (prior && prior.commandHash !== authorization.commandHash) fail('IDEMPOTENCY_CONFLICT');
    if (prior) return Object.freeze({ ...structuredClone(prior.result), replayed: true });
    const snapshot = structuredClone(this.#state);
    try {
      this.reconcile(authorization.tenantId);
      const saleId = command.payload.saleId;
      if (!/^SYNTHETIC-SALE-/.test(saleId ?? '') || !Number.isInteger(command.payload.amountCents) || command.payload.amountCents <= 0) fail('INVALID_COMMAND');
      const entries = this.#tenantEntries(authorization.tenantId), current = entries.get(saleId);
      if (!current) fail('RESOURCE_NOT_FOUND');
      if (current.kind !== 'receivable' || current.status === 'settled') fail('INVALID_STATE_TRANSITION');
      if (current.settledCents + command.payload.amountCents > current.amountCents) fail('RECEIVABLE_OVERPAYMENT');
      const settledCents = current.settledCents + command.payload.amountCents;
      const entry = Object.freeze({ ...current, settledCents, status: settledCents === current.amountCents ? 'settled' : 'open' });
      entries.set(saleId, entry);
      if (command.payload.injectFailure === 'SYNTHETIC-AFTER-SETTLEMENT') fail('INTERNAL_FAILURE');
      const result = Object.freeze({ status: entry.status, entry, reconciliation: this.reconcile(authorization.tenantId), replayed: false });
      this.#state.inbox.set(authorization.idempotencyKey, { commandHash: authorization.commandHash, result });
      this.#state.events.push(Object.freeze({ tenantId: authorization.tenantId, saleId, amountCents: command.payload.amountCents, kind: 'receivable-settlement' }));
      return result;
    } catch (error) { this.#state = snapshot; throw error; }
  }
  snapshot(tenantId) { const reconciliation = this.reconcile(tenantId); return Object.freeze({ entries: Object.freeze([...this.#tenantEntries(tenantId).values()]), reconciliation }); }
  evidence() { return Object.freeze({ commands: this.#state.inbox.size, events: this.#state.events.length, persisted: false, remoteAccessed: false, productionAccessed: false }); }
}

export function createFinanceApplication({ authorizer, store }) {
  if (!authorizer?.authorize || !store?.execute) fail('CONTEXT_RESOLUTION_FAILED');
  return Object.freeze({ async execute({ host, command }) { const authorization = await authorizer.authorize({ host, command }); return store.execute(authorization, command); } });
}
