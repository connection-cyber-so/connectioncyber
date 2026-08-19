import assert from 'node:assert/strict';
import test from 'node:test';
import {
  decidePortalAccess,
  isMembershipActive,
  type PortalMembership,
} from '../src/domain/portal-access.ts';

const now = new Date('2026-08-18T15:00:00-03:00');
const centralHost = { kind: 'central' as const, hostname: 'portal.connectioncyber.com.br' };
const tenantAHost = {
  kind: 'tenant' as const,
  hostname: 'empresa-a.connectioncyber.com.br',
  tenantId: 'tenant-a',
  tenantName: 'Empresa A',
  tenantSlug: 'empresa-a',
};

function membership(overrides: Partial<PortalMembership> = {}): PortalMembership {
  return {
    id: 'membership-a',
    tenantId: 'tenant-a',
    userId: 'user-a',
    status: 'active',
    isDefault: true,
    startsAt: null,
    endsAt: null,
    tenantName: 'Empresa A',
    tenantSlug: 'empresa-a',
    ...overrides,
  };
}

test('domínio desconhecido termina em 404 antes do login', () => {
  assert.equal(
    decidePortalAccess({
      host: { kind: 'invalid', hostname: null },
      userId: null,
      memberships: [],
      now,
    }).kind,
    'not-found'
  );
});

test('host válido sem sessão solicita login', () => {
  assert.equal(
    decidePortalAccess({ host: tenantAHost, userId: null, memberships: [], now }).kind,
    'login'
  );
});

test('host da empresa exige membership do mesmo tenant', () => {
  const decision = decidePortalAccess({
    host: tenantAHost,
    userId: 'user-a',
    memberships: [membership({ tenantId: 'tenant-b' })],
    now,
  });
  assert.equal(decision.kind, 'forbidden');
});

test('membership de outro usuário nunca autoriza, mesmo no tenant correto', () => {
  const decision = decidePortalAccess({
    host: tenantAHost,
    userId: 'user-a',
    memberships: [membership({ userId: 'staff-user' })],
    now,
  });
  assert.equal(decision.kind, 'forbidden');
});

test('membership ativa e compatível autoriza o portal', () => {
  const decision = decidePortalAccess({
    host: tenantAHost,
    userId: 'user-a',
    memberships: [membership()],
    now,
  });
  assert.equal(decision.kind, 'authorized');
});

test('membership suspensa, futura ou expirada não fica ativa', () => {
  assert.equal(isMembershipActive(membership({ status: 'suspended' }), 'user-a', now), false);
  assert.equal(
    isMembershipActive(membership({ startsAt: '2026-08-19T00:00:00Z' }), 'user-a', now),
    false
  );
  assert.equal(
    isMembershipActive(membership({ endsAt: '2026-08-18T17:59:59Z' }), 'user-a', now),
    false
  );
});

test('portal central sem membership exibe estado seguro', () => {
  assert.equal(
    decidePortalAccess({ host: centralHost, userId: 'user-a', memberships: [], now }).kind,
    'no-membership'
  );
});

test('portal central entra direto com uma membership', () => {
  assert.equal(
    decidePortalAccess({ host: centralHost, userId: 'user-a', memberships: [membership()], now })
      .kind,
    'authorized'
  );
});

test('portal central exige seleção ordenada quando há várias memberships', () => {
  const decision = decidePortalAccess({
    host: centralHost,
    userId: 'user-a',
    memberships: [
      membership({ id: 'membership-b', tenantId: 'tenant-b', tenantName: 'Beta' }),
      membership({ id: 'membership-a', tenantId: 'tenant-a', tenantName: 'Alfa' }),
    ],
    now,
  });
  assert.equal(decision.kind, 'select-membership');
  if (decision.kind === 'select-membership') {
    assert.deepEqual(decision.memberships.map((item) => item.tenantName), ['Alfa', 'Beta']);
  }
});

test('cookie só seleciona membership ativa do próprio usuário', () => {
  const decision = decidePortalAccess({
    host: centralHost,
    userId: 'user-a',
    selectedMembershipId: 'membership-staff',
    memberships: [
      membership(),
      membership({ id: 'membership-staff', userId: 'staff-user', tenantId: 'tenant-b' }),
    ],
    now,
  });
  assert.equal(decision.kind, 'authorized');
  if (decision.kind === 'authorized') assert.equal(decision.membership.id, 'membership-a');
});
