import test from 'node:test';
import assert from 'node:assert/strict';
import { syntheticCommand } from '../src/index.mjs';
import { createSyntheticAuthorizationDoubles } from '../src/doubles.mjs';
import { COMMAND_POLICY, createServerCommandAuthorizer } from '../src/server-authorizer.mjs';

const host = 'synthetic-me.connectioncyber.invalid';
const command = () => syntheticCommand('sale.complete', 1, { sale: 'SYNTHETIC-SALE', quantity: 1, amountCents: 100 });
const setup = (overrides = {}) => { const doubles = createSyntheticAuthorizationDoubles(overrides); return { doubles, authorizer: createServerCommandAuthorizer({ ...doubles, clock: () => new Date('2026-08-31T12:00:00.000Z') }) }; };

test('política cobre todos os sete comandos', () => assert.equal(Object.keys(COMMAND_POLICY).length, 7));
test('fluxo autorizado deriva contexto completo no servidor', async () => { const { authorizer } = setup(); const result = await authorizer.authorize({ host, command: command() }); assert.deepEqual([result.tenantId, result.actorId, result.capability, result.permission, result.serverResolved], ['SYNTHETIC-TENANT-ME-001', 'SYNTHETIC-ACTOR-OWNER-001', 'sales.pos', 'sales.manage', true]); });
test('porta no host é normalizada', async () => assert.equal((await setup().authorizer.authorize({ host: `${host}:3011`, command: command() })).tenantId, 'SYNTHETIC-TENANT-ME-001'));
test('host desconhecido é negado', async () => assert.rejects(setup().authorizer.authorize({ host: 'unknown.invalid', command: command() }), /TENANT_NOT_FOUND/));
test('host malformado é negado', async () => assert.rejects(setup().authorizer.authorize({ host: 'bad..host', command: command() }), /TENANT_NOT_FOUND/));
test('sessão ausente é negada', async () => assert.rejects(setup({ identity: { async currentSession() { return null; } } }).authorizer.authorize({ host, command: command() }), /SESSION_REQUIRED/));
test('tenant suspenso é negado', async () => assert.rejects(setup({ tenants: { async resolveActiveByHost() { return { id: 'SYNTHETIC-TENANT-ME-001', status: 'suspended' }; } } }).authorizer.authorize({ host, command: command() }), /TENANT_NOT_FOUND/));
test('membership ausente é negada', async () => assert.rejects(setup({ memberships: { async resolveActive() { return null; } } }).authorizer.authorize({ host, command: command() }), /MEMBERSHIP_REQUIRED/));
test('membership de outro tenant é negada', async () => assert.rejects(setup({ memberships: { async resolveActive(userId) { return { id: 'SYNTHETIC-M', tenantId: 'SYNTHETIC-TENANT-OTHER', userId, role: 'operator', active: true, permissions: ['sales.manage'] }; } } }).authorizer.authorize({ host, command: command() }), /TENANT_HOST_MISMATCH/));
test('owner sem aal2 é negado', async () => assert.rejects(setup({ identity: { async currentSession() { return { userId: 'SYNTHETIC-ACTOR-OWNER-001', aal: 'aal1' }; } } }).authorizer.authorize({ host, command: command() }), /MFA_REQUIRED/));
test('permissão ausente é negada', async () => assert.rejects(setup({ memberships: { async resolveActive(userId, tenantId) { return { id: 'SYNTHETIC-M', tenantId, userId, role: 'operator', active: true, permissions: [] }; } } }).authorizer.authorize({ host, command: command() }), /PERMISSION_REQUIRED/));
test('capacidade disabled é negada', async () => assert.rejects(setup({ capabilities: { async resolveEffective() { return [{ key: 'sales.pos', status: 'disabled' }]; } } }).authorizer.authorize({ host, command: command() }), /CAPABILITY_REQUIRED/));
test('capacidade desconhecida não libera comando', async () => assert.rejects(setup({ capabilities: { async resolveEffective() { return [{ key: 'unknown', status: 'active' }]; } } }).authorizer.authorize({ host, command: command() }), /CAPABILITY_REQUIRED/));
test('tenant no comando continua proibido', async () => assert.rejects(setup().authorizer.authorize({ host, command: { ...command(), tenantId: 'SYNTHETIC-TENANT-ME-001' } }), /AUTHORITY_FIELD_FORBIDDEN/));
test('falha de dependência vira erro público seguro', async () => { const { authorizer } = setup({ identity: { async currentSession() { throw new Error('raw database detail'); } } }); await assert.rejects(authorizer.authorize({ host, command: command() }), error => error.code === 'CONTEXT_RESOLUTION_FAILED' && error.publicError.publicCode === 'OPERATION_FAILED' && !error.message.includes('database')); });
test('autorização gera uma evidência sem payload', async () => { const { authorizer, doubles } = setup(); await authorizer.authorize({ host, command: command() }); assert.equal(doubles.events.length, 1); assert.equal('payload' in doubles.events[0], false); assert.match(doubles.events[0].contextFingerprint, /^[a-f0-9]{64}$/); });
test('negação gera evidência mínima sem payload ou host', async () => { const { authorizer, doubles } = setup({ capabilities: { async resolveEffective() { return []; } } }); await assert.rejects(authorizer.authorize({ host, command: command() }), /CAPABILITY_REQUIRED/); assert.deepEqual([doubles.events[0].event, doubles.events[0].reasonCode], ['command.denied', 'CAPABILITY_REQUIRED']); assert.equal('payload' in doubles.events[0] || 'host' in doubles.events[0], false); });
test('context fingerprint é determinístico', async () => { const first = await setup().authorizer.authorize({ host, command: command() }); const second = await setup().authorizer.authorize({ host, command: command() }); assert.equal(first.contextFingerprint, second.contextFingerprint); });
test('dublês não acessam rede ou persistência', () => { const source = createSyntheticAuthorizationDoubles.toString(); assert.doesNotMatch(source, /fetch\(|supabase|createClient|\.from\(/i); });
