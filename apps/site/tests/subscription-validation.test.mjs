import assert from 'node:assert/strict';
import test from 'node:test';
import { parseTenantSignup, slugify } from '../src/lib/subscriptionValidation.ts';

const VALID = {
  displayName: 'Mercado do Zé',
  legalName: 'Jose Comercio ME',
  cnpj: '12.345.678/0001-99',
  stateRegistration: 'isento123',
  vertical: 'varejo',
};

test('slugify normaliza nome em slug válido', () => {
  assert.equal(slugify('Mercado do Zé'), 'mercado-do-ze');
  assert.equal(slugify('  123 Loja!!  '), 'empresa-123-loja');
  assert.equal(slugify('###'), '');
});

test('aceita cadastro completo e deriva slug/dominio', () => {
  const parsed = parseTenantSignup(VALID);
  assert.ok(parsed);
  assert.equal(parsed.slug, 'mercado-do-ze');
  assert.equal(parsed.domain, 'mercado-do-ze.connectioncyber.com.br');
  assert.equal(parsed.stateRegistration, 'ISENTO123');
  assert.equal(parsed.tradeName, 'Mercado do Zé');
  assert.equal(parsed.establishmentCode, 'MATRIZ');
});

test('aceita slug e dominio explícitos', () => {
  const parsed = parseTenantSignup({ ...VALID, slug: 'meu-mercado', domain: 'meu-mercado.com.br' });
  assert.equal(parsed?.slug, 'meu-mercado');
  assert.equal(parsed?.domain, 'meu-mercado.com.br');
});

test('rejeita CNPJ incompleto, IE malformada e vertical desconhecida', () => {
  assert.equal(parseTenantSignup({ ...VALID, cnpj: '123' }), null);
  assert.equal(parseTenantSignup({ ...VALID, stateRegistration: 'a-b' }), null);
  assert.equal(parseTenantSignup({ ...VALID, vertical: 'Vertical Espaço' }), null);
});

test('rejeita campos obrigatórios ausentes ou não-string', () => {
  assert.equal(parseTenantSignup(null), null);
  assert.equal(parseTenantSignup([]), null);
  assert.equal(parseTenantSignup({ ...VALID, displayName: '' }), null);
  assert.equal(parseTenantSignup({ ...VALID, legalName: 42 }), null);
  assert.equal(parseTenantSignup({ ...VALID, displayName: 'x' }), null);
});

test('não aceita campos fora da allow-list influenciarem a saída', () => {
  const parsed = parseTenantSignup({
    ...VALID,
    password: 'segredo',
    tenantId: '00000000-0000-0000-0000-000000000000',
  });
  assert.ok(parsed);
  assert.deepEqual(Object.keys(parsed).sort(), [
    'cnpj',
    'displayName',
    'domain',
    'establishmentCode',
    'legalName',
    'slug',
    'stateRegistration',
    'tradeName',
    'vertical',
  ]);
});
