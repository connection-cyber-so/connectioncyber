const { securityHeaders } = require('../../config/security-headers');

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // i18n nativo do Next.js removido de propósito: a troca de idioma do site
  // usa LanguageContext (estado React, sem prefixo de URL) — ter os dois ao
  // mesmo tempo duplicava páginas (/pt-BR/*, /en-US/*) que nada linkava e
  // era o principal suspeito por trás de um NOT_FOUND na raiz "/" na Vercel.
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**.supabase.co' },
    ],
  },
  async headers() {
    return [{ source: '/:path*', headers: securityHeaders }];
  },
};

module.exports = nextConfig;
