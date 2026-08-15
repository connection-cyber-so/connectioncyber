import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { env, isSupabaseConfigured } from '@/config/env';

/**
 * Cliente Supabase para uso em Server Components, Route Handlers e Server
 * Actions. Lê a sessão dos cookies da requisição — é ESTE cliente que deriva
 * o usuário/tenant autenticado no servidor, nunca um dado enviado pelo
 * Client Component. Camada central do modelo de isolamento do projeto.
 */
export async function createClient() {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Supabase não configurado. Preencha NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY no .env.local (aponte para o projeto de staging).'
    );
  }

  const cookieStore = await cookies();

  return createServerClient(env.supabase.url, env.supabase.anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Chamado a partir de um Server Component (sem permissão de escrita em cookies).
          // Inofensivo aqui porque o middleware já cuida de renovar a sessão a cada request.
        }
      },
    },
  });
}
