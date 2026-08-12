import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';
import ptBR from '@/i18n/pt-BR.json';
import enUS from '@/i18n/en-US.json';

export type Locale = 'pt-BR' | 'en-US';

const dictionaries: Record<Locale, Record<string, any>> = {
  'pt-BR': ptBR,
  'en-US': enUS,
};

interface LanguageContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (path: string) => any;
}

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

function resolvePath(dict: Record<string, any>, path: string): any {
  return path.split('.').reduce<any>((acc, key) => (acc == null ? acc : acc[key]), dict);
}

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>('pt-BR');

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    if (typeof window !== 'undefined') {
      window.localStorage.setItem('cc-locale', next);
      document.documentElement.lang = next;
    }
  }, []);

  const t = useCallback(
    (path: string) => {
      const value = resolvePath(dictionaries[locale], path);
      return value ?? path;
    },
    [locale]
  );

  const value = useMemo(() => ({ locale, setLocale, t }), [locale, setLocale, t]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error('useLanguage deve ser usado dentro de <LanguageProvider>');
  }
  return ctx;
}
