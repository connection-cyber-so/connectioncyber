import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { env, isSupabaseConfigured } from '@/config/env';

/**
 * Cliente Supabase para uso no browser e em getServerSideProps/getStaticProps.
 * Usa a chave anônima (respeita RLS). Para operações administrativas,
 * use `supabaseAdmin` em código server-only (API routes).
 */
let browserClient: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Supabase não configurado. Preencha NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY no .env.local'
    );
  }
  if (!browserClient) {
    browserClient = createClient(env.supabase.url, env.supabase.anonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
      },
    });
  }
  return browserClient;
}

/**
 * Cliente administrativo (service role) — usar SOMENTE em API routes /
 * código server-side. Nunca importar este módulo em componentes de cliente.
 */
export function getSupabaseAdminClient(): SupabaseClient {
  if (!env.supabase.url || !env.supabase.serviceRoleKey) {
    throw new Error(
      'Supabase admin não configurado. Preencha SUPABASE_SECRET_KEY no .env.local (server-only).'
    );
  }
  return createClient(env.supabase.url, env.supabase.serviceRoleKey, {
    auth: { persistSession: false },
  });
}
