import { createBrowserClient } from '@supabase/ssr';
import { env, isSupabaseConfigured } from '@/config/env';

/**
 * Cliente Supabase para uso em Client Components (formulários, interações).
 * Usa a chave anônima — respeita RLS. Nunca usar a service role aqui.
 */
export function createClient() {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Supabase não configurado. Preencha NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY no .env.local (aponte para o projeto de staging).'
    );
  }
  return createBrowserClient(env.supabase.url, env.supabase.anonKey);
}
