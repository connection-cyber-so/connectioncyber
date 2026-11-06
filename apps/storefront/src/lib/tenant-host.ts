import { createClient } from "@supabase/supabase-js";

/**
 * Resolve o tenant pelo hostname da requisição.
 *
 * Fonte da verdade: RPC public.portal_resolve_host (migration 0017), que só
 * devolve domínios com status 'active' e verified_at preenchido.
 *
 * Fail-closed: erro de rede, RPC com erro ou host desconhecido → null.
 * Erros não são cacheados.
 *
 * Exceção controlada: localhost, 127.0.0.1 e *.vercel.app usam
 * STOREFRONT_DEFAULT_TENANT_ID, mas só fora de produção (VERCEL_ENV !== 'production'
 * e NODE_ENV !== 'production'). Em produção essa variável nem é lida.
 */

export const TENANT_HEADER = "x-cc-tenant-id";

const CACHE_TTL_MS = 60_000;
const cache = new Map<string, { tenantId: string | null; expires: number }>();

export function normalizeRequestHost(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const value = raw.trim().toLowerCase();
  if (!value) return null;
  // IPv6 entre colchetes: [::1]:3000 -> ::1
  if (value.startsWith("[")) {
    const end = value.indexOf("]");
    return end > 0 ? value.slice(1, end) : null;
  }
  const withoutPort = value.split(":")[0];
  return withoutPort || null;
}

function devDefaultTenantId(host: string): string | null {
  const isLocal = host === "localhost" || host === "127.0.0.1" || host === "::1";
  const isPreview = host.endsWith(".vercel.app");
  if (!isLocal && !isPreview) return null;
  if (process.env.NODE_ENV === "production" || process.env.VERCEL_ENV === "production") return null;
  return process.env.STOREFRONT_DEFAULT_TENANT_ID || null;
}

export async function resolveTenantIdByHost(host: string): Promise<string | null> {
  const fallback = devDefaultTenantId(host);
  if (fallback) return fallback;

  const cached = cache.get(host);
  if (cached && cached.expires > Date.now()) return cached.tenantId;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;

  try {
    const supabase = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    });
    const { data, error } = await supabase.rpc("portal_resolve_host", { p_hostname: host });
    if (error) return null;

    const row = Array.isArray(data) ? data[0] : null;
    const tenantId = row && typeof row.tenant_id === "string" ? row.tenant_id : null;
    cache.set(host, { tenantId, expires: Date.now() + CACHE_TTL_MS });
    return tenantId;
  } catch {
    return null;
  }
}
