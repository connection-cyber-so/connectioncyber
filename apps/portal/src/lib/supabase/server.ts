import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { env, isSupabaseConfigured } from '@/config/env';

export async function createClient() {
  if (!isSupabaseConfigured) {
    throw new Error(
      'Supabase do portal não configurado. Use exclusivamente as variáveis do ambiente staging.'
    );
  }

  const cookieStore = await cookies();

  return createServerClient(env.supabase.url, env.supabase.publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
        } catch {
          // Server Components não podem gravar cookies. O middleware renova a sessão.
        }
      },
    },
  });
}
