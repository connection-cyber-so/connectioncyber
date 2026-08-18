/**
 * Leitura centralizada de variáveis de ambiente do painel interno.
 * Mesmo padrão de apps/site/src/config/env.ts.
 */
export const env = {
  supabase: {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL ?? '',
    anonKey:
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '',
    serviceRoleKey: process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
  },
  platform: {
    url: process.env.NEXT_PUBLIC_PLATFORM_URL ?? 'http://localhost:3011',
  },
  site: {
    // Domínio público (apps/site) — usado só para montar o link de landing
    // pages publicadas (módulo Landing Pages), nunca para autenticação.
    url: process.env.NEXT_PUBLIC_SITE_URL ?? 'https://www.connectioncyber.com.br',
  },
};

/** Indica se as chaves do Supabase foram configuradas (evita crash em dev sem .env). */
export const isSupabaseConfigured =
  env.supabase.url.length > 0 && env.supabase.anonKey.length > 0;
