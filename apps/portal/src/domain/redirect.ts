const ALLOWED_PATHS = new Set(['/', '/dashboard', '/selecionar-empresa']);

export function safePortalRedirect(value: FormDataEntryValue | string | null | undefined): string {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//')) return '/';
  if (value.includes('\\') || /[\u0000-\u001f\u007f]/.test(value)) return '/';

  try {
    const parsed = new URL(value, 'https://portal.connectioncyber.com.br');
    if (parsed.origin !== 'https://portal.connectioncyber.com.br') return '/';
    if (!ALLOWED_PATHS.has(parsed.pathname)) return '/';
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return '/';
  }
}
