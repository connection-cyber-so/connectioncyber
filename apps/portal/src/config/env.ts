function parseHostList(value: string | undefined): string[] {
  return (value ?? 'portal.connectioncyber.com.br')
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
}

export const env = {
  supabase: {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL ?? '',
    publishableKey:
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
      '',
  },
  portal: {
    url: process.env.NEXT_PUBLIC_PORTAL_URL ?? 'http://localhost:3021',
    centralHostnames: parseHostList(process.env.PORTAL_CENTRAL_HOSTS),
    allowLocalhost: process.env.NODE_ENV !== 'production',
  },
};

export const isSupabaseConfigured =
  env.supabase.url.length > 0 && env.supabase.publishableKey.length > 0;
