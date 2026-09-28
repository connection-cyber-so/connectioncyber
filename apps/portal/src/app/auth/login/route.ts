import { NextResponse, type NextRequest } from 'next/server';
import { isSupabaseConfigured } from '@/config/env';
import { isSameOriginRequest } from '@/domain/request-origin';
import { safePortalRedirect } from '@/domain/redirect';
import { resolvePortalHost } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';

function loginError(request: NextRequest, code: string, redirectPath: string) {
  const url = new URL('/login', request.url);
  url.searchParams.set('erro', code);
  url.searchParams.set('redirect', redirectPath);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const formData = await request.formData();
  const email = String(formData.get('email') ?? '').trim().toLowerCase();
  const password = String(formData.get('password') ?? '');
  const redirectPath = safePortalRedirect(formData.get('redirect'));

  if (!isSupabaseConfigured) return loginError(request, 'configuracao', redirectPath);
  if (!/^\S+@\S+\.\S+$/.test(email) || password.length < 8) {
    return loginError(request, 'credenciais', redirectPath);
  }

  const supabase = await createClient();
  try {
    const host = await resolvePortalHost(supabase, request.nextUrl.hostname);
    if (host.kind === 'invalid') {
      return new NextResponse(null, {
        status: 404,
        headers: { 'Cache-Control': 'private, no-store' },
      });
    }
  } catch {
    return new NextResponse(null, {
      status: 503,
      headers: { 'Cache-Control': 'private, no-store', 'Retry-After': '30' },
    });
  }

  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) return loginError(request, 'credenciais', redirectPath);

  return NextResponse.redirect(new URL(redirectPath, request.url), 303);
}
