import test from 'node:test';
import assert from 'node:assert/strict';
import { syntheticCommand, validateCommand, syntheticContext } from '../src/index.mjs';
import { createSyntheticAuthorizationDoubles } from '../src/doubles.mjs';
import { createServerCommandAuthorizer } from '../src/server-authorizer.mjs';
import { createMasterDataApplication, MemoryMasterDataStore } from '../src/master-data-application.mjs';
import { createOperationsApplication, MemoryOperationsStore } from '../src/operations-application.mjs';
import { createFinanceApplication, MemoryFinanceStore } from '../src/finance-application.mjs';

const host = 'synthetic-me.connectioncyber.invalid', tenantId = 'SYNTHETIC-TENANT-ME-001';
const setup = async () => {
  const authorizer = createServerCommandAuthorizer({ ...createSyntheticAuthorizationDoubles(), clock: () => new Date('2026-08-31T12:00:00.000Z') });
  const master = new MemoryMasterDataStore(), masterApp = createMasterDataApplication({ authorizer, store: master });
  await masterApp.execute({ host, command: syntheticCommand('catalog.item.create', 1, { marker: 'SYNTHETIC', kind: 'product', code: 'SYNTHETIC-001', name: 'SYNTHETIC PRODUCT', trackInventory: true, allowsFraction: false, priceCents: 1000 }) });
  const operations = new MemoryOperationsStore({ catalog: master }), operationsApp = createOperationsApplication({ authorizer, store: operations });
  await operationsApp.execute({ host, command: syntheticCommand('inventory.receive', 2, { marker: 'SYNTHETIC', itemCode: 'SYNTHETIC-001', quantity: 10 }) });
  await operationsApp.execute({ host, command: syntheticCommand('cash.open', 3, { register: 'SYNTHETIC CASH', openingAmountCents: 5000 }) });
  const saleCommand = syntheticCommand('sale.complete', 4, { saleCode: 'SYNTHETIC CREDIT SALE', paymentMethod: 'SYNTHETIC CREDIT', paymentKind: 'credit', lines: [{ itemCode: 'SYNTHETIC-001', quantity: 2 }], amountCents: 1 });
  const sale = await operationsApp.execute({ host, command: saleCommand });
  const finance = new MemoryFinanceStore({ operations }), financeApp = createFinanceApplication({ authorizer, store: finance });
  return { authorizer, operations, operationsApp, saleCommand, sale, finance, financeApp };
};

test('aliases de autoridade são recusados sem diferenciar maiúsculas', () => {
  for (const field of ['TenantId', 'TENANTID', 'ActorID', 'PriceTotal', 'CashBalance']) assert.throws(() => validateCommand({ ...syntheticCommand('party.create', 90, { marker: 'SYNTHETIC' }), [field]: 'SYNTHETIC-INJECTED' }, syntheticContext()), /AUTHORITY_FIELD_FORBIDDEN/);
});
test('duas vendas concorrentes idênticas geram um único efeito', async () => { const { operationsApp, operations, saleCommand } = await setup(); const replayCommand = syntheticCommand('sale.complete', 5, { ...saleCommand.payload, saleCode: 'SYNTHETIC CASH SALE', paymentMethod: 'SYNTHETIC CASH', paymentKind: 'cash', lines: [{ itemCode: 'SYNTHETIC-001', quantity: 1 }] }); const results = await Promise.all([operationsApp.execute({ host, command: replayCommand }), operationsApp.execute({ host, command: replayCommand })]); assert.deepEqual([results.filter(result => result.replayed).length, operations.snapshot(tenantId).sales.length, operations.snapshot(tenantId).stock['SYNTHETIC-001']], [1, 2, 7]); });
test('comandos concorrentes divergentes com mesma chave não aplicam ambos', async () => { const { operationsApp, operations } = await setup(); const first = syntheticCommand('sale.complete', 5, { saleCode: 'SYNTHETIC CASH A', paymentMethod: 'SYNTHETIC CASH', paymentKind: 'cash', lines: [{ itemCode: 'SYNTHETIC-001', quantity: 1 }], amountCents: 1 }), second = syntheticCommand('sale.complete', 5, { ...first.payload, saleCode: 'SYNTHETIC CASH B' }); const results = await Promise.allSettled([operationsApp.execute({ host, command: first }), operationsApp.execute({ host, command: second })]); assert.deepEqual([results.filter(result => result.status === 'fulfilled').length, results.filter(result => result.reason?.code === 'IDEMPOTENCY_CONFLICT').length, operations.snapshot(tenantId).sales.length], [1, 1, 2]); });
test('duas baixas concorrentes idênticas liquidam uma única vez', async () => { const { financeApp, finance, sale } = await setup(); const command = syntheticCommand('finance.receivable.settle', 6, { marker: 'SYNTHETIC', saleId: sale.sale.id, amountCents: 2000 }); const results = await Promise.all([financeApp.execute({ host, command }), financeApp.execute({ host, command })]); assert.deepEqual([results.filter(result => result.replayed).length, finance.snapshot(tenantId).reconciliation.settledReceivablesCents, finance.evidence().events], [1, 2000, 1]); });
test('baixas concorrentes que excedem saldo aplicam somente uma', async () => { const { financeApp, finance, sale } = await setup(); const first = syntheticCommand('finance.receivable.settle', 6, { marker: 'SYNTHETIC A', saleId: sale.sale.id, amountCents: 1500 }), second = syntheticCommand('finance.receivable.settle', 7, { marker: 'SYNTHETIC B', saleId: sale.sale.id, amountCents: 1500 }); const results = await Promise.allSettled([financeApp.execute({ host, command: first }), financeApp.execute({ host, command: second })]); assert.deepEqual([results.filter(result => result.status === 'fulfilled').length, results.filter(result => result.reason?.code === 'RECEIVABLE_OVERPAYMENT').length, finance.snapshot(tenantId).reconciliation.settledReceivablesCents], [1, 1, 1500]); });
test('mutação do comando durante autorização falha antes do repositório', async () => { const { authorizer, operations, saleCommand } = await setup(); const command = syntheticCommand('sale.complete', 8, { ...saleCommand.payload, saleCode: 'SYNTHETIC MUTATION' }); const authorization = await authorizer.authorize({ host, command }); command.payload.lines[0].quantity = 9; assert.throws(() => operations.execute(authorization, command), /AUTHORIZATION_CONTEXT_MISMATCH/); assert.equal(operations.snapshot(tenantId).sales.length, 1); });
test('fronteira financeira não expõe reconciliação sem autorização', async () => { const { financeApp } = await setup(); assert.deepEqual(Object.keys(financeApp), ['execute']); });
test('evidências adversariais permanecem locais', async () => { const { operations, finance } = await setup(); assert.equal([operations.evidence(), finance.evidence()].some(e => e.persisted || e.remoteAccessed || e.productionAccessed), false); });
