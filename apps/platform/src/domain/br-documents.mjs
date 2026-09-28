// M20-G6 — validação/formatação real de CPF/CNPJ, compartilhada entre o formulário de
// cadastro (client) e a validação server-side (parties/validations.ts). Módulo .mjs puro
// (sem TS) seguindo o mesmo padrão de src/domain/redirect.mjs, pra ser testável direto com
// `node --test` sem loader de TypeScript.

export function onlyDigits(value) {
  return typeof value === 'string' ? value.replace(/\D/g, '') : '';
}

function hasRepeatedDigits(digits) {
  return /^(\d)\1*$/.test(digits);
}

export function isValidCPF(value) {
  const digits = onlyDigits(value);
  if (digits.length !== 11 || hasRepeatedDigits(digits)) return false;

  const calcCheckDigit = (base) => {
    let sum = 0;
    for (let i = 0; i < base.length; i++) sum += Number(base[i]) * (base.length + 1 - i);
    const remainder = (sum * 10) % 11;
    return remainder === 10 ? 0 : remainder;
  };

  const d1 = calcCheckDigit(digits.slice(0, 9));
  const d2 = calcCheckDigit(digits.slice(0, 9) + d1);
  return digits === digits.slice(0, 9) + String(d1) + String(d2);
}

export function isValidCNPJ(value) {
  const digits = onlyDigits(value);
  if (digits.length !== 14 || hasRepeatedDigits(digits)) return false;

  const calcCheckDigit = (base) => {
    const weights = base.length === 12 ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2] : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    let sum = 0;
    for (let i = 0; i < base.length; i++) sum += Number(base[i]) * weights[i];
    const remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  };

  const d1 = calcCheckDigit(digits.slice(0, 12));
  const d2 = calcCheckDigit(digits.slice(0, 12) + d1);
  return digits === digits.slice(0, 12) + String(d1) + String(d2);
}

export function isValidTaxId(value) {
  const digits = onlyDigits(value);
  if (digits.length === 11) return isValidCPF(digits);
  if (digits.length === 14) return isValidCNPJ(digits);
  return false;
}

export function formatCPF(value) {
  const d = onlyDigits(value).slice(0, 11);
  return d
    .replace(/^(\d{3})(\d)/, '$1.$2')
    .replace(/^(\d{3})\.(\d{3})(\d)/, '$1.$2.$3')
    .replace(/\.(\d{3})(\d{1,2})$/, '.$1-$2');
}

export function formatCNPJ(value) {
  const d = onlyDigits(value).slice(0, 14);
  return d
    .replace(/^(\d{2})(\d)/, '$1.$2')
    .replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3')
    .replace(/\.(\d{3})(\d)/, '.$1/$2')
    .replace(/(\d{4})(\d{1,2})$/, '$1-$2');
}

// Formata progressivamente enquanto o usuário digita, escolhendo CPF ou CNPJ pela
// quantidade de dígitos já informada (até 11 assume CPF, de 12 em diante assume CNPJ).
export function formatTaxId(value) {
  const d = onlyDigits(value);
  return d.length > 11 ? formatCNPJ(d) : formatCPF(d);
}

export function formatPhone(value) {
  const d = onlyDigits(value).slice(0, 11);
  if (d.length <= 10) {
    return d.replace(/^(\d{2})(\d)/, '($1) $2').replace(/(\d{4})(\d{1,4})$/, '$1-$2');
  }
  return d.replace(/^(\d{2})(\d)/, '($1) $2').replace(/(\d{5})(\d{1,4})$/, '$1-$2');
}
