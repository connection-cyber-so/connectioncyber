import { readFile } from 'node:fs/promises';

const REQUIRED_MIGRATIONS = Object.freeze({
  foundation: '0016_erp_foundation.sql',
  identity: '0018_identity_rbac_mfa_hardening.sql',
  capabilities: '0032_m16_tenant_capabilities.sql',
});

export const SAFE_ORDER = Object.freeze([
  'resolve_protected_values_in_memory',
  'validate_auth_email_absence',
  'validate_tenant_domain_tax_id_absence',
  'open_server_only_provisioning_run',
  'create_tenant_establishment_roles_capabilities_in_transaction',
  'enqueue_auth_invitation_outbox_in_same_transaction',
  'commit_database_transaction',
  'dispatch_auth_invitation_idempotently_after_commit',
  'bind_auth_user_profile_membership_roles_in_new_transaction',
  'require_aal2_before_privileged_use',
  'complete_ledger_and_post_verify',
]);

export const MAPPING = Object.freeze([
  ['tenant', 'public.tenants', 'direct_server_only'],
  ['establishment', 'public.erp_establishments', 'direct_server_only'],
  ['capabilities', 'public.erp_set_tenant_capability', 'service_role_rpc'],
  ['auth_identity', 'auth.users', 'admin_api_after_commit'],
  ['profile', 'public.users', 'auth_trigger_then_server_verify'],
  ['membership', 'public.erp_tenant_memberships', 'direct_server_only'],
  ['role', 'public.erp_roles', 'direct_server_only'],
  ['role_binding', 'public.erp_membership_roles', 'direct_server_only'],
  ['run', 'public.erp_identity_provisioning_runs', 'service_role_ledger'],
  ['step', 'public.erp_identity_provisioning_steps', 'service_role_ledger'],
]);

export const BLOCKERS = Object.freeze([
  'NO_ATOMIC_PROVISIONING_RPC',
  'LEDGER_ACTION_ALLOWLIST_INCOMPLETE_FOR_TENANT_FLOW',
  'NO_DURABLE_AUTH_INVITATION_OUTBOX',
  'AUTH_AND_POSTGRES_CANNOT_SHARE_TRANSACTION',
  'NO_STATE_REGISTRATION_COLUMN_ON_ESTABLISHMENT',
  'NO_COMPENSATION_CONTRACT_FOR_ORPHAN_AUTH_IDENTITY',
]);

export async function auditPilotMapping(migrationsDirectory) {
  const entries = await Promise.all(Object.values(REQUIRED_MIGRATIONS).map(async file => [file, await readFile(new URL(file, migrationsDirectory), 'utf8')]));
  const sql = Object.fromEntries(entries);
  const assertions = {
    tenantScopedMembership: /create table public\.erp_tenant_memberships/i.test(sql[REQUIRED_MIGRATIONS.foundation]),
    establishmentHasCnpj: /cnpj\s+text check/i.test(sql[REQUIRED_MIGRATIONS.foundation]),
    stateRegistrationMissing: !/state_registration|inscricao_estadual/i.test(sql[REQUIRED_MIGRATIONS.foundation]),
    authTriggerProfileOnly: /Cria somente o profile da identidade/i.test(sql[REQUIRED_MIGRATIONS.identity]),
    ledgerServerOnly: /somente service_role/i.test(sql[REQUIRED_MIGRATIONS.identity]),
    capabilityRpcBrokerOnly: /erp_set_tenant_capability[\s\S]+broker only/i.test(sql[REQUIRED_MIGRATIONS.capabilities]),
    noAtomicProvisioningRpc: !/create or replace function public\.erp_provision_pilot/i.test(Object.values(sql).join('\n')),
    noInvitationOutbox: !/create table public\.erp_auth_invitation_outbox/i.test(Object.values(sql).join('\n')),
  };
  if (Object.values(assertions).some(value => value !== true)) throw new Error('M18_G15_MAPPING_EVIDENCE_INCOMPLETE');
  return Object.freeze({ marker: 'M18_G15_MAPPING_AUDIT_OK', readyForRemoteApply: false, mappingCount: MAPPING.length, safeOrderCount: SAFE_ORDER.length, blockers: [...BLOCKERS], assertions });
}
