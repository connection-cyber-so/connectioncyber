/**
 * Validação do cadastro de empresa enviado pelo navegador na assinatura.
 * Espelha, server-side, as regras da RPC saas_create_checkout_intent_v1 —
 * o navegador NÃO é confiável e nenhum campo é aceito sem conferência.
 * Módulo puro (sem I/O) — coberto por node:test em tests/.
 */

export interface TenantSignupInput {
  slug: string;
  domain: string;
  displayName: string;
  vertical: string;
  legalName: string;
  tradeName: string;
  cnpj: string;
  stateRegistration: string;
  establishmentCode: string;
}

export const VERTICALS = [
  'varejo',
  'servicos',
  'saude',
  'educacao',
  'industria',
  'alimentacao',
  'construcao',
  'tecnologia',
] as const;

const SLUG_PATTERN = /^[a-z][a-z0-9-]{2,63}$/;
const DOMAIN_PATTERN = /^[a-z0-9-]+(\.[a-z0-9-]+)+$/;
const CNPJ_PATTERN = /^[0-9]{14}$/;
const IE_PATTERN = /^[A-Z0-9]{2,20}$/;
const VERTICAL_PATTERN = /^[a-z][a-z0-9_-]{1,60}$/;
const ESTABLISHMENT_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]{1,30}$/;
const DISPLAY_NAME_PATTERN = /^.{2,120}$/;
const LEGAL_NAME_PATTERN = /^.{2,160}$/;
const TRADE_NAME_PATTERN = /^.{2,160}$/;

/** Deriva um slug estável a partir do nome da empresa. */
export function slugify(input: string): string {
  const base = input
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');
  if (!base) return '';
  return /^[a-z]/.test(base) ? base : `empresa-${base}`.slice(0, 64).replace(/-+$/g, '');
}

function text(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

/**
 * Normaliza e valida o payload de cadastro. Retorna `null` quando qualquer
 * campo é inválido (fail-closed: nada é preenchido "por conta própria").
 */
export function parseTenantSignup(raw: unknown): TenantSignupInput | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const input = raw as Record<string, unknown>;

  const displayName = text(input.displayName);
  const legalName = text(input.legalName);
  const tradeName = text(input.tradeName) || displayName;
  const cnpj = text(input.cnpj).replace(/\D/g, '');
  const stateRegistration = text(input.stateRegistration).toUpperCase();
  const vertical = text(input.vertical).toLowerCase();
  const establishmentCode = text(input.establishmentCode) || 'MATRIZ';

  const slug = text(input.slug) || slugify(displayName);
  const domain = text(input.domain).toLowerCase() || (slug ? `${slug}.connectioncyber.com.br` : '');

  if (!DISPLAY_NAME_PATTERN.test(displayName)) return null;
  if (!LEGAL_NAME_PATTERN.test(legalName)) return null;
  if (!TRADE_NAME_PATTERN.test(tradeName)) return null;
  if (!CNPJ_PATTERN.test(cnpj)) return null;
  if (!IE_PATTERN.test(stateRegistration)) return null;
  if (!VERTICAL_PATTERN.test(vertical)) return null;
  if (!SLUG_PATTERN.test(slug)) return null;
  if (!DOMAIN_PATTERN.test(domain)) return null;
  if (!ESTABLISHMENT_PATTERN.test(establishmentCode)) return null;

  return {
    slug,
    domain,
    displayName,
    vertical,
    legalName,
    tradeName,
    cnpj,
    stateRegistration,
    establishmentCode,
  };
}
