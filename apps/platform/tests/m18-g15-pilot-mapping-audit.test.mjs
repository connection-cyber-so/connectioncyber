import assert from 'node:assert/strict';
import test from 'node:test';
import { auditPilotMapping, BLOCKERS, MAPPING, SAFE_ORDER } from '../scripts/pilot-provisioning-mapping-audit.mjs';

const migrations = new URL('../../../supabase/migrations/', import.meta.url);

test('auditoria estática confirma evidências e mantém aplicação bloqueada', async () => {
  const result = await auditPilotMapping(migrations);
  assert.equal(result.marker, 'M18_G15_MAPPING_AUDIT_OK');
  assert.equal(result.readyForRemoteApply, false);
  assert.equal(Object.values(result.assertions).every(Boolean), true);
});

test('mapeamento cobre dez alvos sem duplicidade', () => {
  assert.equal(MAPPING.length, 10);
  assert.equal(new Set(MAPPING.map(([key]) => key)).size, MAPPING.length);
});

test('ordem segura grava banco antes de chamar Auth', () => {
  assert.ok(SAFE_ORDER.indexOf('commit_database_transaction') < SAFE_ORDER.indexOf('dispatch_auth_invitation_idempotently_after_commit'));
});

test('membership é vinculada somente depois da identidade Auth', () => {
  assert.ok(SAFE_ORDER.indexOf('dispatch_auth_invitation_idempotently_after_commit') < SAFE_ORDER.indexOf('bind_auth_user_profile_membership_roles_in_new_transaction'));
});

test('uso privilegiado exige AAL2 antes da conclusão', () => {
  assert.ok(SAFE_ORDER.includes('require_aal2_before_privileged_use'));
});

test('seis bloqueios impedem criação efetiva', () => {
  assert.equal(BLOCKERS.length, 6);
  assert.ok(BLOCKERS.includes('AUTH_AND_POSTGRES_CANNOT_SHARE_TRANSACTION'));
  assert.ok(BLOCKERS.includes('NO_DURABLE_AUTH_INVITATION_OUTBOX'));
});

test('nenhum alvo autoriza escrita pelo navegador', () => {
  assert.equal(MAPPING.some(([, , mode]) => /browser|client|authenticated/.test(mode)), false);
});
