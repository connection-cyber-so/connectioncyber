import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { env, isSupabaseConfigured } from '@/config/env';

const PUBLIC_PATHS = ['/login'];

/**
 * Renova a sessão a cada request e bloqueia rotas não-públicas sem sessão
 * válida. É a primeira camada do modelo de isolamento (JWT → servidor deriva
 * o usuário da sessão, nunca de dado enviado pelo cliente) — mesmo padrão de
 * apps/site/src/middleware.ts, adaptado ao helper oficial do @supabase/ssr
 * para App Router.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request: { headers: request.headers } });

  const { pathname } = request.nextUrl;
  const isPublic = PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(`${p}/`));

  if (!isSupabaseConfigured) {
    if (!isPublic) {
      const url = request.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('redirect', pathname);
      return NextResponse.redirect(url);
    }
    return response;
  }

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

  // getUser() (não getSession()) — valida o JWT contra o servidor Supabase
  // em vez de só ler o cookie, essencial em código que roda no edge/servidor.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user && !isPublic) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('redirect', pathname);
    return NextResponse.redirect(url);
  }

  if (user && pathname === '/login') {
    const url = request.nextUrl.clone();
    url.pathname = '/';
    url.searchParams.delete('redirect');
    return NextResponse.redirect(url);
  }

  return response;
}
