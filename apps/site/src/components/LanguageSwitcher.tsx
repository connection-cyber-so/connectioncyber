import React from 'react';
import { useLanguage, Locale } from '@/context/LanguageContext';

const OPTIONS: { value: Locale; label: string }[] = [
  { value: 'pt-BR', label: 'PT' },
  { value: 'en-US', label: 'EN' },
];

export default function LanguageSwitcher() {
  const { locale, setLocale } = useLanguage();

  return (
    <div style={styles.wrapper} role="group" aria-label="Seletor de idioma">
      {OPTIONS.map((opt) => (
        <button
          key={opt.value}
          onClick={() => setLocale(opt.value)}
          aria-pressed={locale === opt.value}
          style={{
            ...styles.btn,
            ...(locale === opt.value ? styles.btnActive : {}),
          }}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  wrapper: {
    display: 'inline-flex',
    border: '1px solid var(--cc-border)',
    borderRadius: 999,
    overflow: 'hidden',
  },
  btn: {
    padding: '6px 12px',
    fontSize: '0.8rem',
    fontWeight: 700,
    background: 'transparent',
    border: 'none',
    cursor: 'pointer',
    color: 'var(--cc-text-muted)',
  },
  btnActive: {
    background: 'var(--cc-primary)',
    color: '#fff',
  },
};
