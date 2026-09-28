#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

const ROLE_ALLOWLIST = new Set(['owner', 'admin', 'manager', 'operator', 'viewer']);
const LIFECYCLE_ALLOWLIST = new Set(['invited', 'active', 'suspended', 'revoked']);
const EMAIL_KIND_ALLOWLIST = new Set(['transient', 'uat_alias', 'real']);
const SECRET_KEY = /(password|access[_-]?token|refresh[_-]?token|service[_-]?role|secret|credential|certificate|pfx)/i;
const SUBJECT_KEY = /^[a-z][a-z0-9._-]{2,95}$/;
const TENANT_REF = /^[a-z][a-z0-9-]{2,63}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export class ManifestValidationError extends Error {
  constructor(issues) {
    super(`IDENTITY_MANIFEST_INVALID: ${issues.join('; ')}`);
    this.name = 'ManifestValidationError';
    this.issues = issues;
  }
}

function canonicalize(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalize(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function findSecretKeys(value, path = '$', issues = []) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => findSecretKeys(item, `${path}[${index}]`, issues));
    return issues;
  }
  if (!value || typeof value !== 'object') return issues;
  for (const [key, nested] of Object.entries(value)) {
    if (SECRET_KEY.test(key)) issues.push(`${path}.${key} é proibido`);
    findSecretKeys(nested, `${path}.${key}`, issues);
  }
  return issues;
}

export function validateManifest(manifest) {
  const issues = findSecretKeys(manifest);

  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
    throw new ManifestValidationError(['manifesto deve ser objeto JSON']);
  }
  if (manifest.schemaVersion !== 1) issues.push('schemaVersion deve ser 1');
  if (manifest.environment !== 'staging') issues.push('G1 permite somente environment=staging');
  if (manifest.mode !== 'dry-run') issues.push('G1 permite somente mode=dry-run');
  if (!SUBJECT_KEY.test(manifest.batchKey ?? '')) issues.push('batchKey inválido');
  if (!Array.isArray(manifest.subjects) || manifest.subjects.length === 0) {
    issues.push('subjects deve conter ao menos uma persona');
  }

  const subjectKeys = new Set();
  const emails = new Set();
  for (const [index, subject] of (manifest.subjects ?? []).entries()) {
    const prefix = `subjects[${index}]`;
    if (!SUBJECT_KEY.test(subject.subjectKey ?? '')) issues.push(`${prefix}.subjectKey inválido`);
    if (subjectKeys.has(subject.subjectKey)) issues.push(`${prefix}.subjectKey duplicado`);
    subjectKeys.add(subject.subjectKey);

    if (!EMAIL.test(subject.email ?? '') || subject.email !== subject.email?.toLowerCase()) {
      issues.push(`${prefix}.email deve ser válido e minúsculo`);
    }
    if (emails.has(subject.email)) issues.push(`${prefix}.email duplicado`);
    emails.add(subject.email);

    if (!EMAIL_KIND_ALLOWLIST.has(subject.emailKind)) issues.push(`${prefix}.emailKind inválido`);
    if (subject.emailKind === 'transient' && !subject.email.endsWith('.invalid')) {
      issues.push(`${prefix}.email transitório deve usar domínio .invalid`);
    }
    if (subject.emailKind === 'uat_alias' && !subject.email.endsWith('@connectioncyber.com.br')) {
      issues.push(`${prefix}.alias UAT deve pertencer à ConnectionCyber`);
    }
    if (subject.emailKind === 'real') issues.push(`${prefix}.email real é proibido no G1`);
    if (!LIFECYCLE_ALLOWLIST.has(subject.lifecycle)) issues.push(`${prefix}.lifecycle inválido`);
    if (typeof subject.requireMfa !== 'boolean') issues.push(`${prefix}.requireMfa deve ser boolean`);
    if (!Array.isArray(subject.memberships)) issues.push(`${prefix}.memberships deve ser array`);
    if (subject.principalType === 'platform_staff' && subject.memberships?.length !== 0) {
      issues.push(`${prefix}.staff de teste não recebe membership ERP`);
    }

    const tenantRefs = new Set();
    let defaults = 0;
    for (const [membershipIndex, membership] of (subject.memberships ?? []).entries()) {
      const memberPrefix = `${prefix}.memberships[${membershipIndex}]`;
      if (!TENANT_REF.test(membership.tenantRef ?? '')) issues.push(`${memberPrefix}.tenantRef inválido`);
      if (tenantRefs.has(membership.tenantRef)) issues.push(`${memberPrefix}.tenantRef duplicado`);
      tenantRefs.add(membership.tenantRef);
      if (!LIFECYCLE_ALLOWLIST.has(membership.status)) issues.push(`${memberPrefix}.status inválido`);
      if (!Array.isArray(membership.roleKeys) || membership.roleKeys.length === 0) {
        issues.push(`${memberPrefix}.roleKeys deve conter papel`);
      }
      for (const role of membership.roleKeys ?? []) {
        if (!ROLE_ALLOWLIST.has(role)) issues.push(`${memberPrefix}.role ${role} não permitido`);
        if ((role === 'owner' || role === 'admin') && subject.requireMfa !== true) {
          issues.push(`${memberPrefix}.${role} exige MFA`);
        }
      }
      if (membership.isDefault) defaults += 1;
      if (membership.status === 'invited' && !membership.invitationExpiresAt) {
        issues.push(`${memberPrefix}.invitationExpiresAt obrigatório para convite`);
      }
      if (membership.invitationExpiresAt && Number.isNaN(Date.parse(membership.invitationExpiresAt))) {
        issues.push(`${memberPrefix}.invitationExpiresAt inválido`);
      }
    }
    if (defaults > 1) issues.push(`${prefix} possui mais de uma membership padrão`);
  }

  if (issues.length > 0) throw new ManifestValidationError(issues);
  return manifest;
}

export function buildDryRunPlan(manifest) {
  validateManifest(manifest);
  const canonical = canonicalize(manifest);
  const manifestSha256 = createHash('sha256').update(canonical).digest('hex');
  const actions = [];

  for (const subject of manifest.subjects) {
    actions.push({ subjectKey: subject.subjectKey, action: 'validate_identity', status: 'planned' });
    actions.push({ subjectKey: subject.subjectKey, action: 'create_auth_identity', status: 'planned' });
    actions.push({ subjectKey: subject.subjectKey, action: 'upsert_profile', status: 'planned' });
    for (const membership of subject.memberships) {
      actions.push({ subjectKey: subject.subjectKey, tenantRef: membership.tenantRef, action: 'upsert_membership', status: 'planned' });
      actions.push({ subjectKey: subject.subjectKey, tenantRef: membership.tenantRef, action: 'assign_roles', roleKeys: [...membership.roleKeys].sort(), status: 'planned' });
    }
    if (subject.requireMfa) actions.push({ subjectKey: subject.subjectKey, action: 'require_mfa', status: 'planned' });
    actions.push({ subjectKey: subject.subjectKey, action: 'write_audit', status: 'planned' });
  }

  return {
    schemaVersion: 1,
    environment: 'staging',
    executionMode: 'dry_run',
    executable: false,
    networkCalls: 0,
    databaseWrites: 0,
    subjectCount: manifest.subjects.length,
    manifestSha256,
    idempotencyKey: `identity:staging:${manifest.batchKey}:${manifestSha256.slice(0, 16)}`,
    actions,
  };
}

export function parseCliArgs(args) {
  if (args.includes('--apply')) throw new Error('IDENTITY_APPLY_BLOCKED_IN_M04_G1');
  const allowed = new Set(['--dry-run', '--manifest']);
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (!allowed.has(argument)) throw new Error(`IDENTITY_ARGUMENT_UNKNOWN: ${argument}`);
    if (argument === '--manifest') index += 1;
  }
  if (!args.includes('--dry-run')) throw new Error('IDENTITY_DRY_RUN_REQUIRED');
  const manifestIndex = args.indexOf('--manifest');
  if (manifestIndex < 0 || !args[manifestIndex + 1]) throw new Error('IDENTITY_MANIFEST_REQUIRED');
  return { manifestPath: args[manifestIndex + 1] };
}

export async function runCli(args) {
  const { manifestPath } = parseCliArgs(args);
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  return buildDryRunPlan(manifest);
}

const isDirectExecution = process.argv[1]
  && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isDirectExecution) {
  runCli(process.argv.slice(2))
    .then((plan) => process.stdout.write(`${JSON.stringify(plan, null, 2)}\n`))
    .catch((error) => {
      process.stderr.write(`${error.message}\n`);
      process.exitCode = 1;
    });
}
