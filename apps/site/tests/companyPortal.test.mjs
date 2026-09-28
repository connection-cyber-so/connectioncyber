import assert from 'node:assert/strict';
import test from 'node:test';
import { buildCompanyPortalLoginUrl } from '../src/domain/companyPortal.ts';

test('monta o subdomínio oficial a partir de um slug', () => {
  assert.equal(buildCompanyPortalLoginUrl('maniademoda'), 'https://maniademoda.connectioncyber.com.br/login');
  assert.equal(buildCompanyPortalLoginUrl(' MANIADEMODA '), 'https://maniademoda.connectioncyber.com.br/login');
});

test('aceita hostname completo (domínio próprio) quando já tem ponto', () => {
  assert.equal(buildCompanyPortalLoginUrl('erp.clienteexemplo.com.br'), 'https://erp.clienteexemplo.com.br/login');
});

test('recusa entrada vazia, com espaço interno, protocolo ou caractere inválido', () => {
  assert.equal(buildCompanyPortalLoginUrl(''), null);
  assert.equal(buildCompanyPortalLoginUrl('   '), null);
  assert.equal(buildCompanyPortalLoginUrl('mania de moda'), null);
  assert.equal(buildCompanyPortalLoginUrl('https://mania'), null);
  assert.equal(buildCompanyPortalLoginUrl('-mania'), null);
  assert.equal(buildCompanyPortalLoginUrl('mania-'), null);
  assert.equal(buildCompanyPortalLoginUrl('mania/../evil'), null);
});
