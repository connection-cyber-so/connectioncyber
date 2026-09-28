import { NextResponse, type NextRequest } from 'next/server';
import { env, isSupabaseConfigured } from '@/config/env';
import { classifyPortalHostname } from '@/domain/hostname';
import { isMembershipActive, type PortalMembership } from '@/domain/portal-access';
import { isSameOriginRequest } from '@/domain/request-origin';
import { ACTIVE_MEMBERSHIP_COOKIE } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';

type MembershipRow = {
  id: string;
  tenant_id: string;
  user_id: string;
  status: PortalMembership['status'];
  is_default: boolean;
  starts_at: string | null;
  ends_at: string | null;
};

function selectionError(request: NextRequest) {
  const url = new URL('/selecionar-empresa', request.url);
  url.searchParams.set('erro', 'membership');
  return NextResponse.redirect(url, 303);
}

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const host = classifyPortalHostname(request.nextUrl.hostname, {
    centralHostnames: env.portal.centralHostnames,
    allowLocalhost: env.portal.allowLocalhost,
  });
  if (host.kind !== 'central' || !isSupabaseConfigured) return selectionError(request);

  const formData = await request.formData();
  const membershipId = String(formData.get('membership_id') ?? '');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(membershipId)) {
    return selectionError(request);
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return NextResponse.redirect(new URL('/login', request.url), 303);

  const { data, error } = await supabase
    .from('erp_tenant_memberships')
    .select('id, tenant_id, user_id, status, is_default, starts_at, ends_at')
    .eq('id', membershipId)
    .eq('user_id', user.id)
    .maybeSingle();

  if (error || !data) return selectionError(request);
  const row = data as MembershipRow;

  const { data: tenant, error: tenantError } = await supabase
    .from('tenants')
    .select('id, nome, slug')
    .eq('id', row.tenant_id)
    .eq('ativo', true)
    .maybeSingle();

  const candidate: PortalMembership = {
    id: row.id,
    tenantId: row.tenant_id,
    userId: row.user_id,
    status: row.status,
    isDefault: row.is_default,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    tenantName: tenant?.nome ?? '',
    tenantSlug: tenant?.slug ?? '',
  };

  if (tenantError || !tenant || !isMembershipActive(candidate, user.id)) {
    return selectionError(request);
  }

  const response = NextResponse.redirect(new URL('/dashboard', request.url), 303);
  response.cookies.set(ACTIVE_MEMBERSHIP_COOKIE, membershipId, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: 60 * 60 * 8,
  });
  return response;
}
