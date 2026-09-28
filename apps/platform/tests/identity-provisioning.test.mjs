import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import {
  ManifestValidationError,
  buildDryRunPlan,
  parseCliArgs,
  validateManifest,
} from '../scripts/identity-provisioning.mjs';

const fixtureUrl = new URL('../fixtures/identity-provisioning.example.json', import.meta.url);
const fixture = JSON.parse(await readFile(fixtureUrl, 'utf8'));

test('manifesto oficial representa as sete personas sem execução', () => {
  const plan = buildDryRunPlan(fixture);
  assert.equal(plan.subjectCount, 7);
  assert.equal(plan.executionMode, 'dry_run');
  assert.equal(plan.executable, false);
  assert.equal(plan.networkCalls, 0);
  assert.equal(plan.databaseWrites, 0);
  assert.match(plan.manifestSha256, /^[0-9a-f]{64}$/);
  assert.match(plan.idempotencyKey, /^identity:staging:m04-g1-personas:/);
});

test('planejamento é determinístico e idempotente', () => {
  assert.deepEqual(buildDryRunPlan(fixture), buildDryRunPlan(structuredClone(fixture)));
});

test('modo apply é bloqueado antes de ler manifesto', () => {
  assert.throws(
    () => parseCliArgs(['--apply', '--manifest', 'qualquer.json']),
    /IDENTITY_APPLY_BLOCKED_IN_M04_G1/,
  );
});

test('dry-run e manifesto são obrigatórios', () => {
  assert.throws(() => parseCliArgs(['--manifest', 'x.json']), /IDENTITY_DRY_RUN_REQUIRED/);
  assert.throws(() => parseCliArgs(['--dry-run']), /IDENTITY_MANIFEST_REQUIRED/);
});

test('e-mail transitório fora de .invalid é recusado', () => {
  const invalid = structuredClone(fixture);
  invalid.subjects[0].email = 'admin@cliente-real.com.br';
  assert.throws(() => validateManifest(invalid), ManifestValidationError);
});

test('owner e admin exigem MFA', () => {
  const invalid = structuredClone(fixture);
  invalid.subjects[0].requireMfa = false;
  assert.throws(() => validateManifest(invalid), /owner exige MFA/);
});

test('segredos são recusados em qualquer profundidade', () => {
  const invalid = structuredClone(fixture);
  invalid.subjects[0].metadata = { nested: { serviceRoleKey: 'never' } };
  assert.throws(() => validateManifest(invalid), /serviceRoleKey é proibido/);
});

test('identidade multiempresa mantém papéis por tenant', () => {
  const plan = buildDryRunPlan(fixture);
  const assignments = plan.actions.filter(
    (action) => action.subjectKey === 'p03_multiempresa' && action.action === 'assign_roles',
  );
  assert.deepEqual(assignments.map((action) => [action.tenantRef, action.roleKeys]), [
    ['tenant-a', ['manager']],
    ['tenant-b', ['viewer']],
  ]);
});

test('staff sem membership não recebe ação ERP de tenant', () => {
  const plan = buildDryRunPlan(fixture);
  const staffActions = plan.actions.filter((action) => action.subjectKey === 'p04_staff_sem_membership');
  assert.equal(staffActions.some((action) => action.action === 'upsert_membership'), false);
  assert.equal(staffActions.some((action) => action.action === 'assign_roles'), false);
});
