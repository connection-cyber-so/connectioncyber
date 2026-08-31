import { payloadHash, validateCommand, fail } from './index.mjs';

export const COMMAND_POLICY = Object.freeze({
  'party.create': { permission: 'parties.manage', capability: 'core.parties' },
  'catalog.item.create': { permission: 'catalog.manage', capability: 'core.catalog' },
  'inventory.receive': { permission: 'inventory.manage', capability: 'inventory.stock' },
  'cash.open': { permission: 'cash.manage', capability: 'sales.pos' },
  'sale.complete': { permission: 'sales.manage', capability: 'sales.pos' },
  'finance.receivable.settle': { permission: 'finance.manage', capability: 'finance' },
  'cash.close': { permission: 'cash.manage', capability: 'sales.pos' },
});

function normalizeHost(raw) {
  if (typeof raw !== 'string') fail('TENANT_NOT_FOUND');
  const host = raw.trim().toLowerCase().replace(/:\d+$/, '').replace(/\.$/, '');
  if (!/^[a-z0-9][a-z0-9.-]{2,252}$/.test(host) || host.includes('..')) fail('TENANT_NOT_FOUND');
  return host;
}

export function createServerCommandAuthorizer({ identity, tenants, memberships, capabilities, audit, clock = () => new Date() }) {
  if (![identity, tenants, memberships, capabilities, audit].every(dependency => dependency && typeof dependency === 'object')) fail('CONTEXT_RESOLUTION_FAILED');
  return Object.freeze({
    async authorize({ host: rawHost, command }) {
      const host = normalizeHost(rawHost);
      let tenantId = null, actorId = null;
      try {
        const session = await identity.currentSession();
        if (!session || !/^SYNTHETIC-ACTOR-/.test(session.userId ?? '')) fail('SESSION_REQUIRED');
        actorId = session.userId;
        const tenant = await tenants.resolveActiveByHost(host);
        if (!tenant || tenant.status !== 'active' || !/^SYNTHETIC-TENANT-/.test(tenant.id ?? '')) fail('TENANT_NOT_FOUND');
        tenantId = tenant.id;
        const membership = await memberships.resolveActive(session.userId, tenant.id);
        if (!membership || membership.active !== true) fail('MEMBERSHIP_REQUIRED');
        if (membership.tenantId !== tenant.id || membership.userId !== session.userId) fail('TENANT_HOST_MISMATCH');
        if (['owner', 'admin'].includes(membership.role) && session.aal !== 'aal2') fail('MFA_REQUIRED');
        const policy = COMMAND_POLICY[command?.type];
        if (!policy) fail('INVALID_COMMAND');
        if (!membership.permissions?.includes(policy.permission)) fail('PERMISSION_REQUIRED');
        const resolved = await capabilities.resolveEffective(tenant.id, clock());
        const enabled = resolved?.filter(item => item.status === 'active' || item.status === 'trial').map(item => item.key) ?? [];
        if (!enabled.includes(policy.capability)) fail('CAPABILITY_REQUIRED');
        const validated = validateCommand(command, { tenantId: tenant.id, actorId: session.userId, membershipActive: true, capabilities: enabled });
        const authorization = Object.freeze({
          tenantId: tenant.id, actorId: session.userId, membershipId: membership.id,
          role: membership.role, capability: policy.capability, permission: policy.permission,
          idempotencyKey: validated.idempotencyKey, commandHash: validated.hash,
          contextFingerprint: payloadHash({ host, tenantId: tenant.id, actorId: session.userId, membershipId: membership.id, capability: policy.capability, permission: policy.permission, capabilityVersion: resolved.version ?? 'SYNTHETIC-V1' }),
          serverResolved: true, authorizedAt: clock().toISOString(),
        });
        await audit.record({ event: 'command.authorized', tenantId: tenant.id, actorId: session.userId, commandType: command.type, requestId: command.requestId, contextFingerprint: authorization.contextFingerprint });
        return authorization;
      } catch (error) {
        try { await audit.record({ event: 'command.denied', tenantId, actorId, commandType: command?.type ?? 'unknown', requestId: command?.requestId ?? null, reasonCode: error?.code ?? 'CONTEXT_RESOLUTION_FAILED' }); } catch { /* evidência indisponível não substitui a negação */ }
        if (error?.code) throw error;
        fail('CONTEXT_RESOLUTION_FAILED');
      }
    },
  });
}
