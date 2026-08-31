import { syntheticCommand } from '../src/index.mjs';
import { createSyntheticAuthorizationDoubles } from '../src/doubles.mjs';
import { createServerCommandAuthorizer } from '../src/server-authorizer.mjs';

const doubles = createSyntheticAuthorizationDoubles();
const authorizer = createServerCommandAuthorizer({ ...doubles, clock: () => new Date('2026-08-31T12:00:00.000Z') });
const authorization = await authorizer.authorize({ host: 'synthetic-me.connectioncyber.invalid', command: syntheticCommand('sale.complete', 1, { sale: 'SYNTHETIC-SALE', quantity: 1, amountCents: 100 }) });
console.log(JSON.stringify({ result: 'M17_G2_SERVER_AUTHORIZATION_OK', tenantResolved: authorization.tenantId, actorResolved: authorization.actorId, capability: authorization.capability, permission: authorization.permission, auditEvents: doubles.events.length, serverResolved: true, remoteAccessed: false, persisted: false, productionAccessed: false }));
