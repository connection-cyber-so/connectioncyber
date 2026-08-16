import React from 'react';
import { socialLinks } from '@/config/routes';
import { env } from '@/config/env';

const WhatsAppIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="#fff" aria-hidden="true">
    <path d="M12 2C6.48 2 2 6.48 2 12c0 1.85.5 3.58 1.35 5.07L2 22l5.11-1.34A9.94 9.94 0 0 0 12 22c5.52 0 10-4.48 10-10S17.52 2 12 2zm5.2 14.2c-.22.62-1.28 1.2-1.77 1.24-.45.04-.9.06-1.45-.09-.34-.09-.77-.25-1.33-.49-2.34-1.01-3.87-3.35-3.99-3.5-.12-.16-.95-1.26-.95-2.4 0-1.14.6-1.7.81-1.93.21-.23.46-.29.61-.29.15 0 .31 0 .44.01.14.01.33-.05.52.4.19.46.65 1.6.71 1.71.06.12.1.26.02.42-.08.16-.12.26-.24.4-.12.14-.25.31-.36.42-.12.12-.24.25-.1.49.14.24.62 1.03 1.34 1.67.92.82 1.7 1.08 1.94 1.2.24.12.38.1.52-.06.14-.16.6-.7.76-.94.16-.24.32-.2.53-.12.21.08 1.35.64 1.58.75.23.11.38.17.44.27.06.1.06.58-.16 1.2z" />
  </svg>
);

const InstagramIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="#fff" strokeWidth="1.8" aria-hidden="true">
    <rect x="3" y="3" width="18" height="18" rx="5" />
    <circle cx="12" cy="12" r="4.2" />
    <circle cx="17.4" cy="6.6" r="1.1" fill="#fff" stroke="none" />
  </svg>
);

const FacebookIcon = () => (
  <svg viewBox="0 0 24 24" width="20" height="20" fill="#fff" aria-hidden="true">
    <path d="M14.5 8.5H16V5.6c-.26-.04-1.15-.11-2.19-.11-2.17 0-3.66 1.32-3.66 3.75v2.26H7.9v3.2h2.25V22h3.3v-7.3h2.24l.36-3.2h-2.6V9.6c0-.62.17-1.1 1.05-1.1z" />
  </svg>
);

const LinkedInIcon = () => (
  <svg viewBox="0 0 24 24" width="20" height="20" fill="#fff" aria-hidden="true">
    <rect x="3" y="8" width="3.2" height="12" rx="0.5" />
    <circle cx="4.6" cy="4.5" r="2" />
    <path d="M10 8h3v1.8c.6-1 1.8-2.1 3.7-2.1 3 0 4.3 2 4.3 5.3V20h-3.2v-6.3c0-1.6-.03-3.6-2.2-3.6-2.2 0-2.5 1.7-2.5 3.5V20H10z" />
  </svg>
);

const YouTubeIcon = () => (
  <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
    <rect x="2.5" y="6" width="19" height="12" rx="3" fill="none" stroke="#fff" strokeWidth="1.8" />
    <path d="M10.5 9.3v5.4l4.8-2.7z" fill="#fff" />
  </svg>
);

const TikTokIcon = () => (
  <svg viewBox="0 0 24 24" width="20" height="20" fill="#fff" aria-hidden="true">
    <path d="M14 3c.4 2 1.9 3.5 3.9 3.8v2.6c-1.4-.1-2.7-.6-3.9-1.4v6.6c0 3-2.4 5.4-5.4 5.4S3.2 17.6 3.2 14.6 5.6 9.2 8.6 9.2c.4 0 .8 0 1.2.1v2.7c-.4-.1-.8-.2-1.2-.2-1.5 0-2.7 1.2-2.7 2.7s1.2 2.7 2.7 2.7 2.8-1.1 2.8-2.6V3h2.6z" />
  </svg>
);

const ICONS: { key: keyof typeof socialLinks; label: string; color: string; Icon: React.FC }[] = [
  { key: 'whatsapp', label: 'WhatsApp', color: '#25D366', Icon: WhatsAppIcon },
  { key: 'instagram', label: 'Instagram', color: '#E1306C', Icon: InstagramIcon },
  { key: 'facebook', label: 'Facebook', color: '#1877F2', Icon: FacebookIcon },
  { key: 'linkedin', label: 'LinkedIn', color: '#0A66C2', Icon: LinkedInIcon },
  { key: 'youtube', label: 'YouTube', color: '#FF0000', Icon: YouTubeIcon },
  { key: 'tiktok', label: 'TikTok', color: '#010101', Icon: TikTokIcon },
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
      {ICONS.map(({ key, label, color, Icon }) => (
        <a
          key={key}
          href={socialLinks[key]}
          target="_blank"
          rel="noreferrer"
          className="floating-social-btn"
          style={{ background: color }}
          aria-label={label}
          title={label}
          onClick={() => trackClick(key)}
        >
          <Icon />
        </a>
      ))}
    </div>
  );
}
