// M19-G4 — validação pura de identidade visual por tenant. Espelha
// exatamente os `check` de supabase/migrations/0035_m19_tenant_branding.sql
// (`^#[0-9a-f]{6}$` e `^https://` + <=2048 chars) — a fronteira de verdade
// continua sendo a RLS/RPC no banco; isto é só pra dar feedback cedo e
// evitar round-trip óbvio.
const HEX_COLOR_PATTERN = /^#[0-9a-f]{6}$/;
const MAX_LOGO_URL_LENGTH = 2048;

export function isValidHexColor(value: string): boolean {
  return HEX_COLOR_PATTERN.test(value.toLowerCase());
}

export function normalizeHexColor(value: string | null | undefined): string | null {
  const trimmed = (value ?? '').trim().toLowerCase();
  if (!trimmed) return null;
  return isValidHexColor(trimmed) ? trimmed : null;
}

export function isValidLogoUrl(value: string): boolean {
  return value.length <= MAX_LOGO_URL_LENGTH && value.startsWith('https://');
}

export function normalizeLogoUrl(value: string | null | undefined): string | null {
  const trimmed = (value ?? '').trim();
  if (!trimmed) return null;
  return isValidLogoUrl(trimmed) ? trimmed : null;
}
