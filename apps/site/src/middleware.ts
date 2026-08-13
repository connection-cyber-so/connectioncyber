// ============================================================================
// PROJETO: connectioncyber (apps/site)
// ARQUIVO: middleware.ts
// ORIGEM: padrão trazido da auditoria multi-projeto (bpo-system-web-os e
//         food-service-os-staging usam exatamente esse formato). Ver
//         docs/auditoria-ecossistema-connectioncyberos.md, item 3.
// DESCRIÇÃO: Protege rotas autenticadas no servidor, antes de qualquer HTML
//            ser enviado — troca o guard só-client-side (ProtectedRoute)
//            por um redirecionamento que acontece na borda. Foi essa
//            ausência que causava o /membros travar em "Verificando
//            acesso…" indefinidamente quando o Supabase não estava
//            configurado (achado da validação local desta sessão).
// ============================================================================
import { NextResponse, type NextRequest } from 'next/server';
import { createServerClient } from '@supabase/ssr';
import { env, isSupabaseConfigured } from '@/config/env';

const PROTECTED_PREFIXES = ['/membros'];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const isProtected = PROTECTED_PREFIXES.some((prefix) => pathname.startsWith(prefix));

  if (!isProtected) {
    return NextResponse.next();
  }

  // Modo demonstração (sem chaves reais do Supabase): não há sessão possível
  // de qualquer forma — manda direto pro login em vez de deixar a página
  // tentar checar e ficar presa.
  if (!isSupabaseConfigured) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('redirect', pathname);
    return NextResponse.redirect(url);
  }

  let response = NextResponse.next({ request: { headers: request.headers } });

  const supabase = createServerClient(env.supabase.url, env.supabase.anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request: { headers: request.headers } });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('redirect', pathname);
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: ['/membros/:path*'],
};
