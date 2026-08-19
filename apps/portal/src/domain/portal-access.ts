export type ResolvedPortalHost =
  | { kind: 'central'; hostname: string }
  | { kind: 'tenant'; hostname: string; tenantId: string; tenantName: string; tenantSlug: string }
  | { kind: 'invalid'; hostname: string | null };

export type PortalMembership = {
  id: string;
  tenantId: string;
  userId: string;
  status: 'invited' | 'active' | 'suspended' | 'revoked';
  isDefault: boolean;
  startsAt: string | null;
  endsAt: string | null;
  tenantName: string;
  tenantSlug: string;
};

export type PortalAccessDecision =
  | { kind: 'not-found' }
  | { kind: 'login'; host: Exclude<ResolvedPortalHost, { kind: 'invalid' }> }
  | { kind: 'forbidden'; host: Exclude<ResolvedPortalHost, { kind: 'invalid' }> }
  | { kind: 'no-membership'; host: Extract<ResolvedPortalHost, { kind: 'central' }> }
  | { kind: 'select-membership'; host: Extract<ResolvedPortalHost, { kind: 'central' }>; memberships: PortalMembership[] }
  | { kind: 'authorized'; host: Exclude<ResolvedPortalHost, { kind: 'invalid' }>; membership: PortalMembership };

type DecidePortalAccessInput = {
  host: ResolvedPortalHost;
  userId: string | null;
  memberships: readonly PortalMembership[];
  selectedMembershipId?: string | null;
  now?: Date;
};

export function isMembershipActive(
  membership: PortalMembership,
  userId: string,
  now = new Date()
): boolean {
  if (membership.userId !== userId || membership.status !== 'active') return false;

  const instant = now.getTime();
  const startsAt = membership.startsAt ? Date.parse(membership.startsAt) : null;
  const endsAt = membership.endsAt ? Date.parse(membership.endsAt) : null;

  if (startsAt !== null && (!Number.isFinite(startsAt) || startsAt > instant)) return false;
  if (endsAt !== null && (!Number.isFinite(endsAt) || endsAt <= instant)) return false;
  return true;
}

export function decidePortalAccess(input: DecidePortalAccessInput): PortalAccessDecision {
  if (input.host.kind === 'invalid') return { kind: 'not-found' };
  if (!input.userId) return { kind: 'login', host: input.host };

  const eligible = input.memberships.filter((membership) =>
    isMembershipActive(membership, input.userId as string, input.now)
  );

  if (input.host.kind === 'tenant') {
    const tenantId = input.host.tenantId;
    const membership = eligible.find((candidate) => candidate.tenantId === tenantId);
    return membership
      ? { kind: 'authorized', host: input.host, membership }
      : { kind: 'forbidden', host: input.host };
  }

  const selected = eligible.find((membership) => membership.id === input.selectedMembershipId);
  if (selected) return { kind: 'authorized', host: input.host, membership: selected };
  if (eligible.length === 0) return { kind: 'no-membership', host: input.host };
  if (eligible.length === 1) return { kind: 'authorized', host: input.host, membership: eligible[0] };

  return {
    kind: 'select-membership',
    host: input.host,
    memberships: [...eligible].sort((a, b) => a.tenantName.localeCompare(b.tenantName, 'pt-BR')),
  };
}
