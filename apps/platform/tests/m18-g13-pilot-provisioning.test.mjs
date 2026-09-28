import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { buildPilotDryRun, parseArgs, PilotManifestError, validatePilotManifest } from '../scripts/pilot-provisioning.mjs';

const manifest = JSON.parse(await readFile(new URL('../fixtures/pilot-provisioning.maniademodas.json', import.meta.url), 'utf8'));
const preflight = await readFile(new URL('../../../supabase/validation/m18_g13_pilot_provisioning_preflight.sql', import.meta.url), 'utf8');

test('manifesto da Mania de Modas produz dry-run não executável', () => {
  const plan = buildPilotDryRun(manifest);
  assert.equal(plan.executionMode, 'dry_run');
  assert.equal(plan.executable, false);
  assert.equal(plan.networkCalls, 0);
  assert.equal(plan.databaseWrites, 0);
  assert.equal(plan.authWrites, 0);
  assert.equal(plan.productionAccessed, false);
  assert.equal(plan.actionCount, 13);
  assert.match(plan.manifestSha256, /^[a-f0-9]{64}$/);
});

test('planejamento é determinístico e idempotente', () => assert.deepEqual(buildPilotDryRun(manifest), buildPilotDryRun(structuredClone(manifest))));
test('sequência termina em auditoria e verificação pós-aplicação', () => assert.deepEqual(buildPilotDryRun(manifest).actions.slice(-2).map(item => item.action), ['plan_audit_evidence', 'plan_post_apply_verification']));
test('apply é bloqueado antes de ler arquivo', () => assert.throws(() => parseArgs(['--apply', '--manifest', 'x.json']), /PILOT_APPLY_BLOCKED_IN_M18_G13/));
test('dry-run e manifesto são obrigatórios', () => { assert.throws(() => parseArgs(['--manifest', 'x.json']), /PILOT_DRY_RUN_REQUIRED/); assert.throws(() => parseArgs(['--dry-run']), /PILOT_MANIFEST_REQUIRED/); });

test('CNPJ direto é recusado', () => {
  const invalid = structuredClone(manifest); invalid.tenant.taxIdRef = '12.345.678/0001-90';
  assert.throws(() => validatePilotManifest(invalid), PilotManifestError);
});

test('e-mail direto é recusado', () => {
  const invalid = structuredClone(manifest); invalid.owner.emailRef = 'owner@example.com';
  assert.throws(() => validatePilotManifest(invalid), /identidade direta/);
});

test('segredos são recusados em qualquer profundidade', () => {
  const invalid = structuredClone(manifest); invalid.owner.metadata = { password: 'never' };
  assert.throws(() => validatePilotManifest(invalid), /password é proibido/);
});

test('owner exige convite MFA e AAL2', () => {
  for (const [key, value] of [['lifecycle', 'active'], ['requireMfa', false], ['requiredAal', 'aal1']]) {
    const invalid = structuredClone(manifest); invalid.owner[key] = value;
    assert.throws(() => validatePilotManifest(invalid), PilotManifestError);
  }
});

test('produção rede e escrita não podem ser habilitadas', () => {
  for (const key of ['writesAllowed', 'networkAllowed', 'productionAllowed']) {
    const invalid = structuredClone(manifest); invalid.controls[key] = true;
    assert.throws(() => validatePilotManifest(invalid), /controles de dry-run inválidos/);
  }
});

test('domínio deve permanecer sob connectioncyber.com.br', () => {
  const invalid = structuredClone(manifest); invalid.tenant.domain = 'maniademoda.example.com';
  assert.throws(() => validatePilotManifest(invalid), /domínio fora/);
});

test('capacidade duplicada é recusada', () => {
  const invalid = structuredClone(manifest); invalid.tenant.capabilities.push('finance');
  assert.throws(() => validatePilotManifest(invalid), /capacidades inválidas/);
});

test('plano contém somente referências, sem identidade direta', () => {
  const serialized = JSON.stringify(buildPilotDryRun(manifest));
  assert.doesNotMatch(serialized, /\d{14}|@|MARIA DOS REMEDIOS/i);
  assert.equal(buildPilotDryRun(manifest).protectedReferences, 4);
});

test('preflight remoto é somente leitura com rollback', () => {
  assert.match(preflight, /begin transaction read only/i);
  assert.match(preflight, /M18_G13_PILOT_PREFLIGHT_OK/);
  assert.match(preflight, /rollback;/i);
  assert.doesNotMatch(preflight, /\b(insert|update|delete|merge|truncate|alter|create|drop|grant|revoke)\b/i);
});
