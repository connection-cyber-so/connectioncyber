import { syntheticCommand } from '../src/index.mjs';
import { createSyntheticAuthorizationDoubles } from '../src/doubles.mjs';
import { createServerCommandAuthorizer } from '../src/server-authorizer.mjs';
import { createMasterDataApplication, MemoryMasterDataStore } from '../src/master-data-application.mjs';

const doubles = createSyntheticAuthorizationDoubles(), store = new MemoryMasterDataStore();
const authorizer = createServerCommandAuthorizer({ ...doubles, clock: () => new Date('2026-08-31T12:00:00.000Z') });
const app = createMasterDataApplication({ authorizer, store }), host = 'synthetic-me.connectioncyber.invalid';
const party = await app.execute({ host, command: syntheticCommand('party.create', 1, { marker: 'SYNTHETIC-MASTER-DATA', kind: 'organization', legalName: 'SYNTHETIC CUSTOMER', tradeName: 'SYNTHETIC SHOP', role: 'customer' }) });
const item = await app.execute({ host, command: syntheticCommand('catalog.item.create', 2, { marker: 'SYNTHETIC-MASTER-DATA', kind: 'product', code: 'SYNTHETIC-001', name: 'SYNTHETIC PRODUCT', trackInventory: true, allowsFraction: false }) });
console.log(JSON.stringify({ result: 'M17_G3_LOCAL_MASTER_DATA_OK', partyId: party.resource.id, itemId: item.resource.id, parties: store.listParties(party.resource.tenantId).length, items: store.listItems(item.resource.tenantId).length, auditEvents: doubles.events.length, ...store.evidence() }));
