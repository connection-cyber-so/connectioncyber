import { createBrowserClient } from '@supabase/ssr';
import { env, isSupabaseConfigured } from '@/config/env';

/**
 * M18-G22 — primeiro uso de client Supabase no browser neste app. Só existe
 * pra uma coisa: /auth/confirm ler o token que o Supabase Auth manda no
 * fragmento da URL (#access_token=...) em convite/link mágico — fragmento
 * nunca chega ao servidor (Server Component/Route Handler não veem
 * `location.hash`), então essa etapa é obrigatoriamente client-side. Todo
 * o resto do app continua 100% formulário sem JS + Route Handler
 * (ver apps/portal/src/app/auth/*), sem outro uso deste client.
 */
export function createClient() {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Supabase não configurado. Preencha NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY no .env.local (aponte para o projeto de staging).'
    );
  }
  return createBrowserClient(env.supabase.url, env.supabase.publishableKey);
}
