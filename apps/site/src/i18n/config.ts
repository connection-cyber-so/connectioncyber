export const LOCALES = ['pt-BR', 'en-US', 'es-419'] as const;
export type Locale = (typeof LOCALES)[number];

export const DEFAULT_LOCALE: Locale = 'pt-BR';
export const LOCALE_STORAGE_KEY = 'cc-locale';

export function isLocale(value: unknown): value is Locale {
  return typeof value === 'string' && LOCALES.includes(value as Locale);
}
