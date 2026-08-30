import assert from 'node:assert/strict';
import test from 'node:test';
import { safePlatformRedirect } from '../src/domain/redirect.mjs';

test('aceita somente rotas internas conhecidas', () => {
  assert.equal(safePlatformRedirect('/vendas?origem=login'), '/vendas?origem=login');
  assert.equal(safePlatformRedirect('/financeiro'), '/financeiro');
});

test('recusa redirect externo, protocol-relative, barra invertida e rota desconhecida', () => {
  assert.equal(safePlatformRedirect('https://evil.example'), '/');
  assert.equal(safePlatformRedirect('//evil.example'), '/');
  assert.equal(safePlatformRedirect('/\\evil.example'), '/');
  assert.equal(safePlatformRedirect('/admin'), '/');
});
