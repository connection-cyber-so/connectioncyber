'use client';

import { useEffect, useState } from 'react';

// M19-G1 — alternador manual de tema. Independente de sessão/tenant: guarda
// só a preferência de exibição do navegador (localStorage), nunca dado de
// negócio. O valor inicial real é aplicado sem flash pelo script inline em
// app/layout.tsx <head>; este componente só sincroniza o rótulo do botão
// depois de montado e alterna a classe em <html> a partir daí.
const STORAGE_KEY = 'cc-theme';

function readTheme(): 'light' | 'dark' {
  if (typeof document === 'undefined') return 'light';
  const root = document.documentElement;
  if (root.classList.contains('dark')) return 'dark';
  if (root.classList.contains('light')) return 'light';
  return typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function ThemeToggle() {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    setTheme(readTheme());
  }, []);

  function toggle() {
    const next = theme === 'dark' ? 'light' : 'dark';
    const root = document.documentElement;
    root.classList.remove('light', 'dark');
    root.classList.add(next);
    try {
      window.localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // localStorage indisponível (modo privado etc.) — alterna só nesta sessão.
    }
    setTheme(next);
  }

  return (
    <button
      type="button"
      className="pf-button pf-button-secondary"
      style={{ width: 'auto', padding: '8px 16px' }}
      onClick={toggle}
      aria-label={theme === 'dark' ? 'Alternar para modo claro' : 'Alternar para modo escuro'}
    >
      {theme === 'dark' ? '☀️ Light' : '🌙 Dark'}
    </button>
  );
}
