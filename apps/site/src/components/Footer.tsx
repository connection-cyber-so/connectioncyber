import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useLanguage } from '@/context/LanguageContext';
import { mainNav, routes, socialLinks } from '@/config/routes';

export default function Footer() {
  const { t } = useLanguage();
  const year = new Date().getFullYear();

  return (
    <footer style={styles.footer}>
      <div className="container" style={styles.grid}>
        <div>
          <div style={styles.brand}>
            <Image src="/logo.png" alt="ConnectionCyber" width={32} height={32} />
            <strong>{t('brand.name')}</strong>
          </div>
          <p style={styles.slogan}>{t('brand.slogan')}</p>
        </div>

        <div>
          <h4 style={styles.colTitle}>{t('nav.home')}</h4>
          <ul style={styles.list}>
            {mainNav.map((item) => (
              <li key={item.key}>
                <Link href={routes[item.key]}>{t(item.labelKey)}</Link>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h4 style={styles.colTitle}>{t('contact.title')}</h4>
          <ul style={styles.list}>
            <li>{t('contact.location')}</li>
            <li>
              <a href={`tel:${t('contact.phone').replace(/[^\d+]/g, '')}`}>{t('contact.phone')}</a>
            </li>
            <li>
              <a href={socialLinks.whatsapp} target="_blank" rel="noreferrer">
                WhatsApp
              </a>
            </li>
            <li>
              <a href={`mailto:${t('contact.email')}`}>{t('contact.email')}</a>
            </li>
          </ul>
        </div>

        <div>
          <h4 style={styles.colTitle}>Legal</h4>
          <ul style={styles.list}>
            <li>
              <Link href="/politica-de-privacidade">{t('footer.privacy')}</Link>
            </li>
            <li>
              <Link href="/termos-de-uso">{t('footer.terms')}</Link>
            </li>
          </ul>
        </div>
      </div>

      <div className="container" style={styles.bottom}>
        <span>
          © {year} {t('brand.name')} — {t('footer.rights')}
        </span>
      </div>
    </footer>
  );
}

const styles: Record<string, React.CSSProperties> = {
  footer: {
    background: 'var(--cc-primary-dark)',
    color: 'var(--cc-gray-200)',
    marginTop: 64,
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
    gap: 32,
    padding: '56px 24px 32px',
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    fontSize: '1.1rem',
    marginBottom: 8,
  },
  slogan: { color: 'var(--cc-gray-400)', fontSize: '0.9rem' },
  colTitle: { color: '#fff', fontSize: '0.9rem', marginBottom: 14 },
  list: { listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 10, fontSize: '0.88rem' },
  bottom: {
    borderTop: '1px solid rgba(255,255,255,0.1)',
    padding: '18px 24px',
    fontSize: '0.8rem',
    color: 'var(--cc-gray-400)',
  },
};
