import React from 'react';
import { socialLinks } from '@/config/routes';
import { env } from '@/config/env';

const ICONS: { key: keyof typeof socialLinks; label: string; color: string; glyph: string }[] = [
  { key: 'whatsapp', label: 'WhatsApp', color: '#25D366', glyph: 'W' },
  { key: 'instagram', label: 'Instagram', color: '#E1306C', glyph: 'I' },
  { key: 'facebook', label: 'Facebook', color: '#1877F2', glyph: 'F' },
  { key: 'linkedin', label: 'LinkedIn', color: '#0A66C2', glyph: 'in' },
  { key: 'youtube', label: 'YouTube', color: '#FF0000', glyph: 'Y' },
  { key: 'tiktok', label: 'TikTok', color: '#010101', glyph: 'T' },
];

/**
 * Botões flutuantes de mídias sociais.
 * Cada clique dispara (best-effort, não bloqueante):
 *  - evento de analytics (window.gtag / dataLayer, se presente)
 *  - webhook n8n de registro de evento (N8N_BASE_URL/webhook/social-click), se configurado
 */
async function trackClick(network: string) {
  try {
    if (typeof window !== 'undefined' && (window as any).gtag) {
      (window as any).gtag('event', 'social_click', { network });
    }
    if (env.n8n.baseUrl) {
      fetch(`${env.n8n.baseUrl}/webhook/social-click`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ network, timestamp: new Date().toISOString() }),
        keepalive: true,
      }).catch(() => undefined);
    }
  } catch {
    // silencioso — tracking nunca deve quebrar a navegação do usuário
  }
}

export default function FloatingSocialButtons() {
  return (
    <div className="floating-social" aria-label="Redes sociais">
      {ICONS.map((item) => (
        <a
          key={item.key}
          href={socialLinks[item.key]}
          target="_blank"
          rel="noreferrer"
          className="floating-social-btn"
          style={{ background: item.color }}
          aria-label={item.label}
          title={item.label}
          onClick={() => trackClick(item.key)}
        >
          {item.glyph}
        </a>
      ))}
    </div>
  );
}
