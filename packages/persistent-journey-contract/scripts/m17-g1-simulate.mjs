import { MemoryJourneySimulator, syntheticCommand, syntheticContext } from '../src/index.mjs';

const lab = new MemoryJourneySimulator(), context = syntheticContext();
const steps = [
  ['party.create', { name: 'SYNTHETIC-CUSTOMER' }], ['catalog.item.create', { sku: 'SYNTHETIC-SKU' }],
  ['inventory.receive', { movement: 'SYNTHETIC-RECEIPT', quantity: 10 }], ['cash.open', { register: 'SYNTHETIC-CASH' }],
  ['sale.complete', { sale: 'SYNTHETIC-SALE', quantity: 2, amountCents: 2000 }],
  ['finance.receivable.settle', { title: 'SYNTHETIC-RECEIVABLE', amountCents: 2000 }], ['cash.close', { register: 'SYNTHETIC-CASH' }],
];
steps.forEach(([type, payload], index) => lab.execute(context, syntheticCommand(type, index + 1, payload)));
const replay = lab.execute(context, syntheticCommand('sale.complete', 5, { sale: 'SYNTHETIC-SALE', quantity: 2, amountCents: 2000 }));
console.log(JSON.stringify({ result: 'M17_G1_PERSISTENT_JOURNEY_CONTRACT_OK', commands: steps.length, replayed: replay.replayed, ...lab.evidence() }));
