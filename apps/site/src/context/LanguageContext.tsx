import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import ptBR from '@/i18n/pt-BR.json';
import enUS from '@/i18n/en-US.json';
import es419 from '@/i18n/es-419.json';
import { DEFAULT_LOCALE, isLocale, LOCALE_STORAGE_KEY, type Locale } from '@/i18n/config';

type TranslationValue = string | TranslationValue[] | { [key: string]: TranslationValue };

const dictionaries: Record<Locale, TranslationValue> = {
  'pt-BR': ptBR,
  'en-US': enUS,
  'es-419': es419,
};

interface LanguageContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (path: string) => string;
  getTranslation: <T extends TranslationValue>(path: string) => T;
}

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

function resolvePath(dict: TranslationValue, path: string): TranslationValue | undefined {
  return path.split('.').reduce<TranslationValue | undefined>((current, key) => {
    if (current === undefined || typeof current !== 'object' || Array.isArray(current)) {
      return undefined;
    }
    return current[key];
  }, dict);
}

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(DEFAULT_LOCALE);

  useEffect(() => {
    try {
      const storedLocale = window.localStorage.getItem(LOCALE_STORAGE_KEY);
      const initialLocale = isLocale(storedLocale) ? storedLocale : DEFAULT_LOCALE;
      setLocaleState(initialLocale);
      document.documentElement.lang = initialLocale;
    } catch {
      document.documentElement.lang = DEFAULT_LOCALE;
    }
  }, []);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    try {
      window.localStorage.setItem(LOCALE_STORAGE_KEY, next);
      document.documentElement.lang = next;
    } catch {
      // O idioma continua funcional em memória quando o armazenamento é bloqueado.
    }
  }, []);

  const t = useCallback((path: string): string => {
    const value = resolvePath(dictionaries[locale], path);
    return typeof value === 'string' ? value : path;
  }, [locale]);

  const getTranslation = useCallback(<T extends TranslationValue,>(path: string): T => {
    const value = resolvePath(dictionaries[locale], path);
    if (value === undefined) {
      throw new Error(`Tradução estruturada não encontrada: ${path}`);
    }
    return value as T;
  }, [locale]);

  const value = useMemo(
    () => ({ locale, setLocale, t, getTranslation }),
    [locale, setLocale, t, getTranslation],
  );

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export type { Locale } from '@/i18n/config';

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error('useLanguage deve ser usado dentro de <LanguageProvider>');
  }
  return ctx;
}
