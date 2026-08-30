const ALLOWED_PATHS = new Set([
  '/', '/cadastros', '/catalogo', '/operacoes', '/vendas', '/pdv', '/financeiro', '/bancos',
  '/servicos', '/alimentacao', '/atendimento', '/identidades', '/tenants', '/diagnostics',
  '/landing-pages', '/offers', '/products', '/video-scripts'
]);

export function safePlatformRedirect(value) {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//')) return '/';
  if (value.includes('\\') || /[\u0000-\u001f\u007f]/.test(value)) return '/';
  try {
    const parsed = new URL(value, 'https://platform.connectioncyber.com.br');
    if (parsed.origin !== 'https://platform.connectioncyber.com.br') return '/';
    if (!ALLOWED_PATHS.has(parsed.pathname)) return '/';
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return '/';
  }
}
