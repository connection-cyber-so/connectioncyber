#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const KEY = /^[a-z][a-z0-9-]{2,63}$/;
const DOMAIN = /^(?!-)[a-z0-9-]+(?:\.[a-z0-9-]+)+$/;
const PROTECTED = /^protected:[A-Z][A-Z0-9_]{2,95}$/;
const FORBIDDEN_KEY = /(password|senha|secret|token|credential|service[_-]?role|certificate|pfx|p12|csc)/i;
const CNPJ = /\b\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}\b/;
const EMAIL = /[^\s@]+@[^\s@]+\.[^\s@]+/;

export class PilotManifestError extends Error {
  constructor(issues) { super(`PILOT_MANIFEST_INVALID: ${issues.join('; ')}`); this.name = 'PilotManifestError'; this.issues = issues; }
}

const canonical = value => Array.isArray(value)
  ? `[${value.map(canonical).join(',')}]`
  : value && typeof value === 'object'
    ? `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`
    : JSON.stringify(value);

function inspect(value, path = '$', issues = []) {
  if (Array.isArray(value)) { value.forEach((item, index) => inspect(item, `${path}[${index}]`, issues)); return issues; }
  if (!value || typeof value !== 'object') return issues;
  for (const [key, nested] of Object.entries(value)) {
    if (FORBIDDEN_KEY.test(key)) issues.push(`${path}.${key} é proibido`);
    if (typeof nested === 'string' && (CNPJ.test(nested) || EMAIL.test(nested))) issues.push(`${path}.${key} contém identidade direta`);
    inspect(nested, `${path}.${key}`, issues);
  }
  return issues;
}

export function validatePilotManifest(manifest) {
  const issues = inspect(manifest);
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) throw new PilotManifestError(['manifesto deve ser objeto']);
  if (manifest.schemaVersion !== 1) issues.push('schemaVersion deve ser 1');
  if (manifest.environment !== 'staging') issues.push('environment deve ser staging');
  if (manifest.mode !== 'dry-run') issues.push('mode deve ser dry-run');
  if (manifest.pilot !== true) issues.push('pilot deve ser true');
  if (!KEY.test(manifest.batchKey ?? '')) issues.push('batchKey inválido');
  const tenant = manifest.tenant ?? {};
  if (!KEY.test(tenant.ref ?? '') || !KEY.test(tenant.slug ?? '')) issues.push('tenant ref/slug inválido');
  if (!DOMAIN.test(tenant.domain ?? '') || !tenant.domain.endsWith('.connectioncyber.com.br')) issues.push('domínio fora de connectioncyber.com.br');
  if (typeof tenant.displayName !== 'string' || tenant.displayName.length < 3) issues.push('displayName inválido');
  for (const field of ['legalNameRef', 'taxIdRef', 'stateRegistrationRef']) if (!PROTECTED.test(tenant[field] ?? '')) issues.push(`${field} deve ser referência protegida`);
  if (!Array.isArray(tenant.capabilities) || tenant.capabilities.length === 0 || new Set(tenant.capabilities).size !== tenant.capabilities.length) issues.push('capacidades inválidas');
  if (tenant.capabilities?.some(item => !KEY.test(item.replaceAll('.', '-')))) issues.push('capacidade inválida');
  const owner = manifest.owner ?? {};
  if (!KEY.test(owner.subjectKey ?? '')) issues.push('owner.subjectKey inválido');
  if (!PROTECTED.test(owner.emailRef ?? '')) issues.push('owner.emailRef deve ser referência protegida');
  if (owner.lifecycle !== 'invited') issues.push('owner deve iniciar como invited');
  if (owner.role !== 'owner') issues.push('owner.role deve ser owner');
  if (owner.requireMfa !== true || owner.requiredAal !== 'aal2') issues.push('owner exige MFA/AAL2');
  if (manifest.controls?.writesAllowed !== false || manifest.controls?.networkAllowed !== false || manifest.controls?.productionAllowed !== false) issues.push('controles de dry-run inválidos');
  if (issues.length) throw new PilotManifestError(issues);
  return manifest;
}

export function buildPilotDryRun(manifest) {
  validatePilotManifest(manifest);
  const hash = createHash('sha256').update(canonical(manifest)).digest('hex');
  const tenantRef = manifest.tenant.ref;
  const actions = [
    ['validate_protected_inputs', null], ['preflight_tenant_absence', tenantRef], ['plan_tenant', tenantRef],
    ['plan_establishment', tenantRef], ['plan_roles', tenantRef], ['plan_capabilities', tenantRef],
    ['plan_auth_invitation', manifest.owner.subjectKey], ['plan_profile', manifest.owner.subjectKey],
    ['plan_membership', tenantRef], ['plan_owner_role', tenantRef], ['plan_mfa_aal2', manifest.owner.subjectKey],
    ['plan_audit_evidence', tenantRef], ['plan_post_apply_verification', tenantRef]
  ].map(([action, targetRef], index) => ({ sequence: index + 1, action, targetRef, status: 'planned', executable: false }));
  return Object.freeze({ schemaVersion: 1, environment: 'staging', executionMode: 'dry_run', pilot: true, executable: false, networkCalls: 0, databaseWrites: 0, authWrites: 0, productionAccessed: false, manifestSha256: hash, idempotencyKey: `pilot:staging:${manifest.batchKey}:${hash.slice(0, 16)}`, protectedReferences: 4, actionCount: actions.length, actions });
}

export function parseArgs(args) {
  if (args.includes('--apply')) throw new Error('PILOT_APPLY_BLOCKED_IN_M18_G13');
  if (!args.includes('--dry-run')) throw new Error('PILOT_DRY_RUN_REQUIRED');
  const index = args.indexOf('--manifest');
  if (index < 0 || !args[index + 1]) throw new Error('PILOT_MANIFEST_REQUIRED');
  if (args.some((arg, position) => !['--dry-run', '--manifest'].includes(arg) && position !== index + 1)) throw new Error('PILOT_ARGUMENT_UNKNOWN');
  return { manifestPath: args[index + 1] };
}

export async function runCli(args) { const { manifestPath } = parseArgs(args); return buildPilotDryRun(JSON.parse(await readFile(manifestPath, 'utf8'))); }
const direct = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (direct) runCli(process.argv.slice(2)).then(plan => process.stdout.write(`M18_G13_PILOT_DRY_RUN_OK ${JSON.stringify(plan)}\n`)).catch(error => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; });
