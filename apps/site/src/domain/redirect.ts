// M19-G5 — mesmo formato de apps/portal/src/domain/redirect.ts. Fecha o gap
// de open-redirect que existia em pages/login/index.tsx (usava
// router.query.redirect cru, sem allowlist nenhuma).
const ALLOWED_PATHS = new Set(['/', '/membros']);
const CONTROL_CHAR_PATTERN = new RegExp('[\\x00-\\x1f\\x7f]');

export function safeSiteRedirect(value: string | string[] | undefined): string {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//')) return '/membros';
  if (value.includes('\\') || CONTROL_CHAR_PATTERN.test(value)) return '/membros';

  try {
    const parsed = new URL(value, 'https://www.connectioncyber.com.br');
    if (parsed.origin !== 'https://www.connectioncyber.com.br') return '/membros';
    if (!ALLOWED_PATHS.has(parsed.pathname)) return '/membros';
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return '/membros';
  }
}
