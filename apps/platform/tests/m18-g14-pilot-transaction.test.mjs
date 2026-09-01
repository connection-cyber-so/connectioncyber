import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { InMemoryPilotUnitOfWork, simulatePilotProvisioning } from '../scripts/pilot-provisioning-transaction.mjs';

const manifest = JSON.parse(await readFile(new URL('../fixtures/pilot-provisioning.maniademodas.json', import.meta.url), 'utf8'));
const references = [manifest.tenant.legalNameRef, manifest.tenant.taxIdRef, manifest.tenant.stateRegistrationRef, manifest.owner.emailRef];
const resolver = { has: reference => references.includes(reference) };

test('simulação transacional conclui sem escrita remota', async () => {
  const uow = new InMemoryPilotUnitOfWork();
  const result = await simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow });
  assert.equal(result.marker, 'M18_G14_LOCAL_TRANSACTION_OK');
  assert.equal(result.remoteWrites, 0);
  assert.equal(result.invitationDispatched, false);
  assert.equal(uow.state.tenants.length, 1);
});

test('convite vira outbox não executável', async () => {
  const uow = new InMemoryPilotUnitOfWork();
  await simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow });
  assert.deepEqual(uow.state.invitationOutbox.map(({ status, executableHere }) => ({ status, executableHere })), [{ status: 'pending', executableHere: false }]);
});

test('identidade permanece representada somente por fingerprints e referências', async () => {
  const uow = new InMemoryPilotUnitOfWork();
  await simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow });
  const serialized = JSON.stringify(uow.state);
  assert.doesNotMatch(serialized, /\d{14}|@/);
  assert.match(serialized, /Fingerprint/);
});

for (const faultAt of ['run', 'tenant', 'establishment', 'membership', 'outbox', 'audit']) test(`falha em ${faultAt} restaura snapshot integral`, async () => {
  const seed = { audit: [{ event: 'baseline' }] };
  const uow = new InMemoryPilotUnitOfWork(seed); const before = uow.snapshot();
  await assert.rejects(simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow, faultAt }), new RegExp(`SIMULATED_FAILURE:${faultAt}`));
  assert.deepEqual(uow.snapshot(), before);
});

test('replay idêntico não duplica entidades', async () => {
  const uow = new InMemoryPilotUnitOfWork();
  const first = await simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow });
  const second = await simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow });
  assert.equal(second.marker, 'M18_G14_LOCAL_REPLAY_OK');
  assert.equal(second.stateHash, first.stateHash);
  assert.equal(uow.state.tenants.length, 1);
});

test('tenant existente com outro run falha fechado', async () => {
  const uow = new InMemoryPilotUnitOfWork({ tenants: [{ slug: manifest.tenant.slug, domain: 'blocked.invalid' }] });
  await assert.rejects(simulatePilotProvisioning({ manifest, resolver, unitOfWork: uow }), /PILOT_TENANT_ALREADY_EXISTS/);
});

test('referência protegida ausente bloqueia antes da transação', async () => {
  const uow = new InMemoryPilotUnitOfWork(); const before = uow.snapshot();
  await assert.rejects(simulatePilotProvisioning({ manifest, resolver: { has: () => false }, unitOfWork: uow }), /PROTECTED_REFERENCE_UNAVAILABLE/);
  assert.deepEqual(uow.snapshot(), before);
});

test('modo remoto e unit of work desconhecida são recusados', async () => {
  await assert.rejects(simulatePilotProvisioning({ manifest, resolver, unitOfWork: new InMemoryPilotUnitOfWork(), mode: 'apply' }), /PILOT_REMOTE_EXECUTION_BLOCKED/);
  await assert.rejects(simulatePilotProvisioning({ manifest, resolver, unitOfWork: {} }), /LOCAL_UNIT_OF_WORK_REQUIRED/);
});
