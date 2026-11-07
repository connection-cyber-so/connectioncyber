import { NextRequest, NextResponse } from "next/server";
import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { permissaoDoModulo } from "@/lib/rbac";
import { normalizeRequestHost, resolveTenantIdByHost, TENANT_HEADER } from "@/lib/tenant-host";

// 1) Resolve o tenant pelo hostname e grava x-cc-tenant-id (apaga o que o cliente enviar).
//    Host desconhecido → 404. Fail-closed.
// 2) Áreas privadas (/crm, /configuracoes, /pdv, /financeiro, /compras, /vendas, /portal,
//    /email, /logistica): exige sessão Supabase Auth, perfil ativo e papel autorizado pelo
//    módulo (RBAC - migrations 0004/0005/0009). Sem env de Supabase, bloqueia com 503.

const PRIVATE_PREFIXES = [
  "/crm",
  "/configuracoes",
  "/logistica",
  "/pdv",
  "/financeiro",
  "/compras",
  "/vendas",
  "/email",
  "/portal",
];

function isPrivatePath(pathname: string): boolean {
  return PRIVATE_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

export async function middleware(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url || !key) {
    return new NextResponse("Area temporariamente indisponivel (credenciais nao configuradas).", {
      status: 503,
    });
  }

  const host = normalizeRequestHost(request.headers.get("host"));
  const tenantId = host ? await resolveTenantIdByHost(host) : null;

  if (!tenantId) {
    return new NextResponse("Endereco nao associado a nenhuma empresa.", { status: 404 });
  }

  // Cabeçalho do cliente é descartado: só o tenant resolvido pelo host segue adiante.
  const requestHeaders = new Headers(request.headers);
  requestHeaders.delete(TENANT_HEADER);
  requestHeaders.set(TENANT_HEADER, tenantId);

  let response = NextResponse.next({ request: { headers: requestHeaders } });

  if (!isPrivatePath(request.nextUrl.pathname)) {
    return response;
  }

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request: { headers: requestHeaders } });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const login = new URL("/login", request.url);
    login.searchParams.set("next", request.nextUrl.pathname);
    return NextResponse.redirect(login);
  }

  const permissao = permissaoDoModulo(request.nextUrl.pathname);
  if (!permissao) {
    return new NextResponse("Acesso restrito: modulo sem permissao mapeada.", { status: 403 });
  }

  const { data: autorizado } = await supabase.rpc("storefront_has_permission", {
    p_tenant_id: tenantId,
    p_permission_key: permissao,
  });

  if (autorizado !== true) {
    return new NextResponse("Acesso restrito: seu acesso nao inclui este modulo nesta empresa.", {
      status: 403,
    });
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:png|jpg|jpeg|webp|gif|svg|mp4|css|js|txt)$).*)"],
};
