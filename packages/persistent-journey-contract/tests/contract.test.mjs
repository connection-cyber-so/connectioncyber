import test from 'node:test';
import assert from 'node:assert/strict';
import { AGGREGATE_STATES, COMMANDS, ERROR_CATALOG, MemoryJourneySimulator, payloadHash, syntheticCommand, syntheticContext, transition, validateCommand } from '../src/index.mjs';

const context = syntheticContext();
test('contrato possui sete comandos canônicos', () => assert.equal(COMMANDS.length, 7));
test('contrato cobre seis agregados', () => assert.equal(Object.keys(AGGREGATE_STATES).length, 6));
test('catálogo de erro não expõe mensagem interna', () => assert.equal(Object.values(ERROR_CATALOG).every(item => item.publicCode && !('message' in item)), true));
test('hash canônico ignora ordem das propriedades', () => assert.equal(payloadHash({ a: 1, b: 2 }), payloadHash({ b: 2, a: 1 })));
test('tenant ausente falha fechado', () => assert.throws(() => validateCommand(syntheticCommand('party.create', 1, { name: 'SYNTHETIC' }), { ...context, tenantId: '' }), /TENANT_CONTEXT_REQUIRED/));
test('membership inativa é recusada', () => assert.throws(() => validateCommand(syntheticCommand('party.create', 1, { name: 'SYNTHETIC' }), { ...context, membershipActive: false }), /MEMBERSHIP_REQUIRED/));
test('tenant enviado pelo navegador é recusado', () => assert.throws(() => validateCommand({ ...syntheticCommand('party.create', 1, { name: 'SYNTHETIC' }), tenantId: context.tenantId }, context), /AUTHORITY_FIELD_FORBIDDEN/));
test('campo de autoridade aninhado é recusado', () => assert.throws(() => validateCommand(syntheticCommand('sale.complete', 1, { name: 'SYNTHETIC', meta: { priceTotal: 1 } }), context), /AUTHORITY_FIELD_FORBIDDEN/));
test('papel técnico no envelope é recusado', () => assert.throws(() => validateCommand({ ...syntheticCommand('party.create', 1, { name: 'SYNTHETIC' }), role: 'owner' }, context), /AUTHORITY_FIELD_FORBIDDEN/));
test('capacidade ausente é recusada', () => assert.throws(() => validateCommand(syntheticCommand('sale.complete', 1, { sale: 'SYNTHETIC', quantity: 1, amountCents: 100 }), { ...context, capabilities: [] }), /CAPABILITY_REQUIRED/));
test('payload sem marcador sintético é recusado', () => assert.throws(() => validateCommand(syntheticCommand('party.create', 1, { name: 'REAL' }), context), /INVALID_COMMAND/));
test('segredo no payload é recusado', () => assert.throws(() => validateCommand(syntheticCommand('party.create', 1, { name: 'SYNTHETIC', password: 'x' }), context), /INVALID_COMMAND/));
test('quantidade não positiva é recusada', () => assert.throws(() => validateCommand(syntheticCommand('inventory.receive', 1, { movement: 'SYNTHETIC', quantity: -1 }), context), /INVALID_COMMAND/));
test('valor monetário não positivo é recusado', () => assert.throws(() => validateCommand(syntheticCommand('sale.complete', 1, { sale: 'SYNTHETIC', quantity: 1, amountCents: 0 }), context), /INVALID_COMMAND/));
test('chave idempotente inclui tenant resolvido e comando', () => assert.match(validateCommand(syntheticCommand('party.create', 1, { name: 'SYNTHETIC' }), context).idempotencyKey, /^m17:v1:SYNTHETIC-TENANT-ME-001:party\.create:/));
test('transição válida é aceita', () => assert.equal(transition('sale', 'reserved', 'completed'), 'completed'));
test('transição inválida é recusada', () => assert.throws(() => transition('sale', 'draft', 'completed'), /INVALID_STATE_TRANSITION/));

function completeJourney(lab = new MemoryJourneySimulator()) {
  const steps = [
    ['party.create', { name: 'SYNTHETIC-CUSTOMER' }], ['catalog.item.create', { sku: 'SYNTHETIC-SKU' }],
    ['inventory.receive', { movement: 'SYNTHETIC-RECEIPT', quantity: 10 }], ['cash.open', { register: 'SYNTHETIC-CASH' }],
    ['sale.complete', { sale: 'SYNTHETIC-SALE', quantity: 2, amountCents: 2000 }],
    ['finance.receivable.settle', { title: 'SYNTHETIC-RECEIVABLE', amountCents: 2000 }], ['cash.close', { register: 'SYNTHETIC-CASH' }],
  ];
  steps.forEach(([type, payload], index) => lab.execute(context, syntheticCommand(type, index + 1, payload)));
  return lab;
}
test('jornada completa reconcilia estado', () => assert.deepEqual(completeJourney().evidence().state, { parties: 1, items: 1, stock: 8, cash: 'closed', sales: 1, receivables: 2000, settled: 2000 }));
test('jornada completa gera sete eventos', () => assert.equal(completeJourney().evidence().events, 7));
test('replay idêntico não duplica efeito', () => { const lab = new MemoryJourneySimulator(), command = syntheticCommand('party.create', 1, { name: 'SYNTHETIC-CUSTOMER' }); lab.execute(context, command); assert.equal(lab.execute(context, command).replayed, true); assert.equal(lab.evidence().state.parties, 1); });
test('mesma chave com payload diferente gera conflito', () => { const lab = new MemoryJourneySimulator(); lab.execute(context, syntheticCommand('party.create', 1, { name: 'SYNTHETIC-A' })); assert.throws(() => lab.execute(context, syntheticCommand('party.create', 1, { name: 'SYNTHETIC-B' })), /IDEMPOTENCY_CONFLICT/); });
test('venda sem caixa aberto falha fechado', () => assert.throws(() => new MemoryJourneySimulator().execute(context, syntheticCommand('sale.complete', 1, { sale: 'SYNTHETIC', quantity: 1, amountCents: 100 })), /INVALID_STATE_TRANSITION/));
test('estoque sem catálogo falha fechado', () => assert.throws(() => new MemoryJourneySimulator().execute(context, syntheticCommand('inventory.receive', 1, { movement: 'SYNTHETIC', quantity: 1 })), /RESOURCE_NOT_FOUND/));
test('falha injetada restaura snapshot integral', () => { const lab = new MemoryJourneySimulator(); assert.throws(() => lab.execute(context, syntheticCommand('party.create', 1, { name: 'SYNTHETIC', injectFailure: 'SYNTHETIC-AFTER-APPLY' })), /INTERNAL_FAILURE/); assert.deepEqual(lab.evidence(), { state: { parties: 0, items: 0, stock: 0, cash: 'closed', sales: 0, receivables: 0, settled: 0 }, events: 0, records: 0, persisted: false, remoteAccessed: false, productionAccessed: false }); });
test('baixa acumulada não supera o recebível', () => { const lab = completeJourney(); assert.throws(() => lab.execute(context, syntheticCommand('finance.receivable.settle', 8, { title: 'SYNTHETIC-SECOND', amountCents: 1 })), /INVALID_STATE_TRANSITION/); });
test('simulador não persiste nem acessa remoto', () => { const evidence = completeJourney().evidence(); assert.equal(evidence.persisted || evidence.remoteAccessed || evidence.productionAccessed, false); });
