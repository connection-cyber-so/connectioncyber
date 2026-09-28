import React, { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/router';
import { useLanguage } from '@/context/LanguageContext';
import { mainNav, routes } from '@/config/routes';
import LanguageSwitcher from './LanguageSwitcher';
import ThemeToggle from './ThemeToggle';

export default function Header() {
  const { t } = useLanguage();
  const router = useRouter();
  const [open, setOpen] = useState(false);

  return (
    <header style={styles.header}>
      <div className="container" style={styles.inner}>
        <Link href={routes.home} style={styles.brand} onClick={() => setOpen(false)}>
          <Image src="/logo.png" alt="ConnectionCyber" width={34} height={34} style={styles.logo} priority />
          <span style={styles.brandText}>{t('brand.name')}</span>
        </Link>

        <nav
          className={`site-nav${open ? ' site-nav-open' : ''}`}
          style={styles.nav}
          aria-label="Navegação principal"
        >
          {mainNav.map((item) => {
            const href = routes[item.key];
            const active = router.pathname === href;
            return (
              <Link
                key={item.key}
                href={href}
                onClick={() => setOpen(false)}
                style={{ ...styles.navLink, ...(active ? styles.navLinkActive : {}) }}
              >
                {t(item.labelKey)}
              </Link>
            );
          })}
        </nav>

        <div style={styles.actions}>
          <ThemeToggle />
          <LanguageSwitcher />
          <Link href={routes.login} className="btn btn-primary" style={styles.ctaBtn}>
            {t('nav.loginCta')}
          </Link>
          <button
            className="nav-burger"
            style={styles.burger}
            aria-label="Abrir menu"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
          >
            ☰
          </button>
        </div>
      </div>
    </header>
  );
}

const styles: Record<string, React.CSSProperties> = {
  header: {
    position: 'sticky',
    top: 0,
    zIndex: 100,
    background: 'var(--cc-bg)',
    borderBottom: '1px solid var(--cc-border)',
    backdropFilter: 'blur(8px)',
  },
  inner: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: 72,
    gap: 16,
  },
  brand: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    fontWeight: 800,
    fontSize: '1.1rem',
    color: 'var(--cc-primary-dark)',
  },
  logo: { height: 34, width: 34 },
  brandText: { whiteSpace: 'nowrap' },
  nav: {
    display: 'flex',
    gap: 22,
    flexWrap: 'wrap',
  },
  navOpen: {},
  navLink: {
    fontSize: '0.92rem',
    fontWeight: 600,
    color: 'var(--cc-text-muted)',
  },
  navLinkActive: {
    color: 'var(--cc-primary)',
  },
  actions: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
  },
  ctaBtn: {
    padding: '10px 18px',
    fontSize: '0.85rem',
    border: '1.5px solid var(--cc-orange)',
  },
  burger: {
    display: 'none',
    background: 'transparent',
    border: 'none',
    fontSize: '1.4rem',
    cursor: 'pointer',
  },
};
