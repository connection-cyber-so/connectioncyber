import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { env, isSupabaseConfigured } from '@/config/env';
import { normalizeHostname } from '@/domain/hostname';

export async function updatePortalSession(request: NextRequest) {
  const requestHeaders = new Headers(request.headers);
  const normalizedHostname = normalizeHostname(request.nextUrl.hostname);
  requestHeaders.set('x-cc-portal-host', normalizedHostname ?? 'invalid');
  // M18-G22 — o gate de MFA (decideMfaGate) precisa saber em qual rota a
  // Server Component já está pra não redirecionar a própria tela de
  // segurança pra ela mesma (loop infinito). Server Components não recebem
  // pathname de outro jeito — mesmo mecanismo já usado pra x-cc-portal-host.
  requestHeaders.set('x-cc-pathname', request.nextUrl.pathname);

  let response = NextResponse.next({ request: { headers: requestHeaders } });
  response.headers.set('Cache-Control', 'private, no-store');

  if (!isSupabaseConfigured) return response;

  const supabase = createServerClient(env.supabase.url, env.supabase.publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request: { headers: requestHeaders } });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options)
        );
        response.headers.set('Cache-Control', 'private, no-store');
      },
    },
  });

  // Valida o JWT no servidor e renova cookies quando necessário.
  await supabase.auth.getUser();
  return response;
}
