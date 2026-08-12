/**
 * Leitura centralizada de variáveis de ambiente.
 * Mantém o resto da aplicação livre de `process.env` espalhado pelo código.
 */
export const env = {
  supabase: {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL ?? '',
    anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY ?? '',
  },
  mercadoPago: {
    accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN ?? '',
    publicKey: process.env.NEXT_PUBLIC_MERCADOPAGO_PUBLIC_KEY ?? '',
    webhookSecret: process.env.MERCADOPAGO_WEBHOOK_SECRET ?? '',
  },
  n8n: {
    baseUrl: process.env.N8N_BASE_URL ?? '',
    webhookToken: process.env.N8N_WEBHOOK_TOKEN ?? '',
  },
  site: {
    url: process.env.NEXT_PUBLIC_SITE_URL ?? 'https://www.connectioncyber.com.br',
    defaultLocale: process.env.NEXT_PUBLIC_DEFAULT_LOCALE ?? 'pt-BR',
  },
};

/** Indica se as chaves do Supabase foram configuradas (evita crash em dev sem .env). */
export const isSupabaseConfigured =
  env.supabase.url.length > 0 && env.supabase.anonKey.length > 0;

/** Indica se as chaves do Mercado Pago foram configuradas. */
export const isMercadoPagoConfigured = env.mercadoPago.accessToken.length > 0;
