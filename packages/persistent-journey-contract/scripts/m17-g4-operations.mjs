import { syntheticCommand } from '../src/index.mjs';
import { createSyntheticAuthorizationDoubles } from '../src/doubles.mjs';
import { createServerCommandAuthorizer } from '../src/server-authorizer.mjs';
import { createMasterDataApplication, MemoryMasterDataStore } from '../src/master-data-application.mjs';
import { createOperationsApplication, MemoryOperationsStore } from '../src/operations-application.mjs';

const host = 'synthetic-me.connectioncyber.invalid', tenantId = 'SYNTHETIC-TENANT-ME-001', doubles = createSyntheticAuthorizationDoubles();
const authorizer = createServerCommandAuthorizer({ ...doubles, clock: () => new Date('2026-08-31T12:00:00.000Z') }), master = new MemoryMasterDataStore(), masterApp = createMasterDataApplication({ authorizer, store: master });
await masterApp.execute({ host, command: syntheticCommand('catalog.item.create', 1, { marker: 'SYNTHETIC', kind: 'product', code: 'SYNTHETIC-001', name: 'SYNTHETIC PRODUCT', trackInventory: true, allowsFraction: false, priceCents: 1000 }) });
const store = new MemoryOperationsStore({ catalog: master }), app = createOperationsApplication({ authorizer, store });
await app.execute({ host, command: syntheticCommand('inventory.receive', 2, { marker: 'SYNTHETIC', itemCode: 'SYNTHETIC-001', quantity: 10 }) });
await app.execute({ host, command: syntheticCommand('cash.open', 3, { register: 'SYNTHETIC CASH', openingAmountCents: 5000 }) });
const saleCommand = syntheticCommand('sale.complete', 4, { saleCode: 'SYNTHETIC SALE', paymentMethod: 'SYNTHETIC CASH', lines: [{ itemCode: 'SYNTHETIC-001', quantity: 2 }], amountCents: 1 });
const sale = await app.execute({ host, command: saleCommand }), replay = await app.execute({ host, command: saleCommand });
await app.execute({ host, command: syntheticCommand('cash.close', 5, { register: 'SYNTHETIC CASH', declaredAmountCents: 7000 }) });
console.log(JSON.stringify({ result: 'M17_G4_LOCAL_OPERATIONS_OK', serverDerivedTotalCents: sale.sale.totalCents, clientHintIgnored: sale.sale.totalCents !== 1, replayed: replay.replayed, snapshot: store.snapshot(tenantId), ...store.evidence() }));
