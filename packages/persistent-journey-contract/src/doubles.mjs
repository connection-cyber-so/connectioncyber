export function createSyntheticAuthorizationDoubles(overrides = {}) {
  const tenant = { id: 'SYNTHETIC-TENANT-ME-001', status: 'active' };
  const session = { userId: 'SYNTHETIC-ACTOR-OWNER-001', aal: 'aal2' };
  const membership = { id: 'SYNTHETIC-MEMBERSHIP-001', tenantId: tenant.id, userId: session.userId, role: 'owner', active: true, permissions: ['parties.manage', 'catalog.manage', 'inventory.manage', 'cash.manage', 'sales.manage', 'finance.manage'] };
  const capabilityRows = Object.assign([
    { key: 'core.parties', status: 'active' }, { key: 'core.catalog', status: 'active' },
    { key: 'inventory.stock', status: 'active' }, { key: 'sales.pos', status: 'active' }, { key: 'finance', status: 'active' },
  ], { version: 'SYNTHETIC-CAPABILITIES-V1' });
  const events = [];
  return {
    identity: overrides.identity ?? { async currentSession() { return session; } },
    tenants: overrides.tenants ?? { async resolveActiveByHost(host) { return host === 'synthetic-me.connectioncyber.invalid' ? tenant : null; } },
    memberships: overrides.memberships ?? { async resolveActive(userId, tenantId) { return userId === session.userId && tenantId === tenant.id ? membership : null; } },
    capabilities: overrides.capabilities ?? { async resolveEffective(tenantId) { return tenantId === tenant.id ? capabilityRows : []; } },
    audit: overrides.audit ?? { async record(event) { events.push(Object.freeze(event)); } },
    events,
    fixtures: { tenant, session, membership, capabilityRows },
  };
}
