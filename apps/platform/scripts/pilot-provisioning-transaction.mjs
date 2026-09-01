#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { buildPilotDryRun, validatePilotManifest } from './pilot-provisioning.mjs';

const ALLOWED_MODE = 'local-simulation';

const clone = value => structuredClone(value);
const fingerprint = reference => createHash('sha256').update(reference).digest('hex').slice(0, 16);

export class PilotTransactionError extends Error {
  constructor(code) { super(code); this.name = 'PilotTransactionError'; this.code = code; }
}

export class InMemoryPilotUnitOfWork {
  constructor(seed = {}) { this.state = clone({ tenants: [], establishments: [], memberships: [], roleBindings: [], capabilityBindings: [], invitationOutbox: [], audit: [], runs: [], ...seed }); }
  snapshot() { return clone(this.state); }
  async transaction(operation) {
    const before = this.snapshot();
    try { return await operation(this.state); }
    catch (error) { this.state = before; throw error; }
  }
}

function assertProtectedResolver(resolver, references) {
  if (!resolver || typeof resolver.has !== 'function') throw new PilotTransactionError('PROTECTED_RESOLVER_REQUIRED');
  for (const reference of references) if (!resolver.has(reference)) throw new PilotTransactionError(`PROTECTED_REFERENCE_UNAVAILABLE:${reference}`);
}

function ensureAbsent(state, manifest) {
  if (state.tenants.some(item => item.slug === manifest.tenant.slug || item.domain === manifest.tenant.domain)) throw new PilotTransactionError('PILOT_TENANT_ALREADY_EXISTS');
}

export async function simulatePilotProvisioning({ manifest, resolver, unitOfWork, mode = ALLOWED_MODE, faultAt = null }) {
  if (mode !== ALLOWED_MODE) throw new PilotTransactionError('PILOT_REMOTE_EXECUTION_BLOCKED');
  validatePilotManifest(manifest);
  if (!(unitOfWork instanceof InMemoryPilotUnitOfWork)) throw new PilotTransactionError('LOCAL_UNIT_OF_WORK_REQUIRED');
  const dryRun = buildPilotDryRun(manifest);
  const references = [manifest.tenant.legalNameRef, manifest.tenant.taxIdRef, manifest.tenant.stateRegistrationRef, manifest.owner.emailRef];
  assertProtectedResolver(resolver, references);
  const runKey = dryRun.idempotencyKey;
  const existing = unitOfWork.state.runs.find(run => run.runKey === runKey && run.status === 'committed');
  if (existing) return Object.freeze({ marker: 'M18_G14_LOCAL_REPLAY_OK', replay: true, runKey, stateHash: existing.stateHash });

  return unitOfWork.transaction(async state => {
    ensureAbsent(state, manifest);
    const fail = step => { if (faultAt === step) throw new PilotTransactionError(`SIMULATED_FAILURE:${step}`); };
    state.runs.push({ runKey, status: 'running', manifestSha256: dryRun.manifestSha256 });
    fail('run');
    state.tenants.push({ ref: manifest.tenant.ref, slug: manifest.tenant.slug, domain: manifest.tenant.domain, displayName: manifest.tenant.displayName, legalNameFingerprint: fingerprint(manifest.tenant.legalNameRef), taxIdFingerprint: fingerprint(manifest.tenant.taxIdRef) });
    fail('tenant');
    state.establishments.push({ tenantRef: manifest.tenant.ref, stateRegistrationFingerprint: fingerprint(manifest.tenant.stateRegistrationRef) });
    state.capabilityBindings.push(...manifest.tenant.capabilities.map(capability => ({ tenantRef: manifest.tenant.ref, capability })));
    fail('establishment');
    state.memberships.push({ tenantRef: manifest.tenant.ref, subjectKey: manifest.owner.subjectKey, lifecycle: 'invited', requireMfa: true, requiredAal: 'aal2' });
    state.roleBindings.push({ tenantRef: manifest.tenant.ref, subjectKey: manifest.owner.subjectKey, role: 'owner' });
    fail('membership');
    state.invitationOutbox.push({ runKey, tenantRef: manifest.tenant.ref, subjectKey: manifest.owner.subjectKey, emailRef: manifest.owner.emailRef, status: 'pending', executableHere: false });
    fail('outbox');
    state.audit.push({ runKey, event: 'pilot.provisioning.simulated', identityValuesStored: false, remoteWrites: 0 });
    fail('audit');
    const stateHash = createHash('sha256').update(JSON.stringify(state)).digest('hex');
    const run = state.runs.find(item => item.runKey === runKey); run.status = 'committed'; run.stateHash = stateHash;
    return Object.freeze({ marker: 'M18_G14_LOCAL_TRANSACTION_OK', replay: false, runKey, stateHash, invitationDispatched: false, remoteWrites: 0, productionAccessed: false });
  });
}
