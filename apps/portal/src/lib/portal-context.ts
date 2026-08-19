import { cache } from 'react';
import { cookies, headers } from 'next/headers';
import { env, isSupabaseConfigured } from '@/config/env';
import { classifyPortalHostname } from '@/domain/hostname';
import {
  decidePortalAccess,
  type PortalAccessDecision,
  type PortalMembership,
  type ResolvedPortalHost,
} from '@/domain/portal-access';
import { createClient } from '@/lib/supabase/server';

export const ACTIVE_MEMBERSHIP_COOKIE = 'cc_portal_membership';

type DomainRow = {
  domain_id: string;
  tenant_id: string;
  tenant_slug: string;
  tenant_name: string;
  hostname: string;
};

type MembershipRow = {
  id: string;
  tenant_id: string;
  user_id: string;
  status: PortalMembership['status'];
  is_default: boolean;
  starts_at: string | null;
  ends_at: string | null;
};

type TenantRow = {
  id: string;
  nome: string;
  slug: string;
};

export type PortalLoadResult =
  | PortalAccessDecision
  | { kind: 'configuration-missing' }
  | { kind: 'service-unavailable' };

type PortalClient = Awaited<ReturnType<typeof createClient>>;

export async function resolvePortalHost(
  supabase: PortalClient,
  rawHostname: string | null
): Promise<ResolvedPortalHost> {
  const classified = classifyPortalHostname(rawHostname, {
    centralHostnames: env.portal.centralHostnames,
    allowLocalhost: env.portal.allowLocalhost,
  });

  if (classified.kind === 'invalid') return { kind: 'invalid', hostname: null };
  if (classified.kind === 'central') return classified;

  const { data, error } = await supabase.rpc('portal_resolve_host', {
    p_hostname: classified.hostname,
  });
  if (error) throw new Error('PORTAL_HOST_RESOLUTION_FAILED');

  const domain = ((data ?? []) as DomainRow[])[0];
  if (!domain) return { kind: 'invalid', hostname: classified.hostname };

  return {
    kind: 'tenant',
    hostname: domain.hostname,
    tenantId: domain.tenant_id,
    tenantName: domain.tenant_name,
    tenantSlug: domain.tenant_slug,
  };
}

async function listMemberships(
  supabase: PortalClient,
  userId: string
): Promise<PortalMembership[]> {
  const { data: membershipData, error: membershipError } = await supabase
    .from('erp_tenant_memberships')
    .select('id, tenant_id, user_id, status, is_default, starts_at, ends_at')
    .eq('user_id', userId);

  if (membershipError) throw new Error('PORTAL_MEMBERSHIP_QUERY_FAILED');

  const membershipRows = (membershipData ?? []) as MembershipRow[];
  const tenantIds = [...new Set(membershipRows.map((item) => item.tenant_id))];
  if (tenantIds.length === 0) return [];

  const { data: tenantData, error: tenantError } = await supabase
    .from('tenants')
    .select('id, nome, slug')
    .in('id', tenantIds)
    .eq('ativo', true);

  if (tenantError) throw new Error('PORTAL_TENANT_QUERY_FAILED');

  const tenants = new Map(
    ((tenantData ?? []) as TenantRow[]).map((tenant) => [tenant.id, tenant])
  );

  return membershipRows.flatMap((membership) => {
    const tenant = tenants.get(membership.tenant_id);
    if (!tenant) return [];
    return [
      {
        id: membership.id,
        tenantId: membership.tenant_id,
        userId: membership.user_id,
        status: membership.status,
        isDefault: membership.is_default,
        startsAt: membership.starts_at,
        endsAt: membership.ends_at,
        tenantName: tenant.nome,
        tenantSlug: tenant.slug,
      } satisfies PortalMembership,
    ];
  });
}

export const loadPortalAccess = cache(async (): Promise<PortalLoadResult> => {
  if (!isSupabaseConfigured) return { kind: 'configuration-missing' };

  try {
    const headerStore = await headers();
    const cookieStore = await cookies();
    const rawHostname =
      headerStore.get('x-cc-portal-host') ?? headerStore.get('host') ?? null;
    const supabase = await createClient();
    const host = await resolvePortalHost(supabase, rawHostname);

    if (host.kind === 'invalid') {
      return decidePortalAccess({ host, userId: null, memberships: [] });
    }

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return decidePortalAccess({ host, userId: null, memberships: [] });
    }

    const memberships = await listMemberships(supabase, user.id);
    return decidePortalAccess({
      host,
      userId: user.id,
      memberships,
      selectedMembershipId: cookieStore.get(ACTIVE_MEMBERSHIP_COOKIE)?.value,
    });
  } catch {
    return { kind: 'service-unavailable' };
  }
});
