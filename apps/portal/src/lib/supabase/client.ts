import { createBrowserClient } from '@supabase/ssr';
import { env, isSupabaseConfigured } from '@/config/env';

/**
 * M18-G22 — client Supabase no browser deste app, com dois usos, ambos
 * exceções deliberadas ao padrão 100% formulário + Route Handler do resto
 * do app: (1) /auth/confirm lê o token que o Supabase Auth manda no
 * fragmento da URL (#access_token=...) em convite/link mágico — fragmento
 * nunca chega ao servidor (Server Component/Route Handler não veem
 * `location.hash`), então essa etapa é obrigatoriamente client-side; (2)
 * SecurityMfaPanel (tela /configuracoes/seguranca) cadastra/valida TOTP —
 * enroll/challenge/verify só fazem sentido contra a sessão viva no
 * navegador, com reação imediata a código errado sem reload de página.
 */
export function createClient() {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Supabase não configurado. Preencha NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY no .env.local (aponte para o projeto de staging).'
    );
  }
  return createBrowserClient(env.supabase.url, env.supabase.publishableKey);
}
