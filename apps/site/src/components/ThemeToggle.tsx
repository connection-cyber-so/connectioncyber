import { useEffect, useState } from 'react';

// M19-G1 — mesmo mecanismo de apps/platform e apps/portal: só guarda a
// preferência de exibição (localStorage), nunca dado de sessão. O valor
// inicial é aplicado sem flash pelo script inline em pages/_document.tsx.
const STORAGE_KEY = 'cc-theme';

function readTheme(): 'light' | 'dark' {
  if (typeof document === 'undefined') return 'light';
  const root = document.documentElement;
  if (root.classList.contains('dark')) return 'dark';
  if (root.classList.contains('light')) return 'light';
  return typeof window !== 'undefined' && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export default function ThemeToggle() {
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
      className="btn btn-outline"
      style={{ padding: '8px 14px', fontSize: '0.85rem' }}
      onClick={toggle}
      aria-label={theme === 'dark' ? 'Alternar para modo claro' : 'Alternar para modo escuro'}
    >
      {theme === 'dark' ? '☀️' : '🌙'}
    </button>
  );
}
