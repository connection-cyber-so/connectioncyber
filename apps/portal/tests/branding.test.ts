import assert from 'node:assert/strict';
import test from 'node:test';
import { isValidHexColor, isValidLogoUrl, normalizeHexColor, normalizeLogoUrl } from '../src/domain/branding.ts';

test('aceita cor hexadecimal de 6 dígitos, maiúscula ou minúscula', () => {
  assert.equal(isValidHexColor('#f6851f'), true);
  assert.equal(isValidHexColor('#F6851F'.toLowerCase()), true);
});

test('recusa cor fora do formato', () => {
  assert.equal(isValidHexColor('laranja'), false);
  assert.equal(isValidHexColor('#fff'), false);
  assert.equal(isValidHexColor('f6851f'), false);
  assert.equal(isValidHexColor('#f6851fff'), false);
});

test('normaliza cor pra minúsculas, ou null se vazia/inválida', () => {
  assert.equal(normalizeHexColor(' #F6851F '), '#f6851f');
  assert.equal(normalizeHexColor(''), null);
  assert.equal(normalizeHexColor(null), null);
  assert.equal(normalizeHexColor('laranja'), null);
});

test('aceita URL https dentro do limite de tamanho', () => {
  assert.equal(isValidLogoUrl('https://cdn.example.invalid/logo.png'), true);
});

test('recusa URL sem https ou acima do limite de tamanho', () => {
  assert.equal(isValidLogoUrl('http://cdn.example.invalid/logo.png'), false);
  assert.equal(isValidLogoUrl('https://' + 'a'.repeat(2048)), false);
});

test('normaliza URL de logo, ou null se vazia/inválida', () => {
  assert.equal(normalizeLogoUrl(' https://cdn.example.invalid/logo.png '), 'https://cdn.example.invalid/logo.png');
  assert.equal(normalizeLogoUrl(''), null);
  assert.equal(normalizeLogoUrl('ftp://cdn.example.invalid/logo.png'), null);
});
