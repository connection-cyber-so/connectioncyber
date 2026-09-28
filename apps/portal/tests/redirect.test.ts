import assert from 'node:assert/strict';
import test from 'node:test';
import { safePortalRedirect } from '../src/domain/redirect.ts';

test('aceita somente destinos internos permitidos', () => {
  assert.equal(safePortalRedirect('/dashboard?origem=login'), '/dashboard?origem=login');
  assert.equal(safePortalRedirect('/selecionar-empresa'), '/selecionar-empresa');
});

test('recusa redirect externo, protocol-relative, barra invertida e rota não permitida', () => {
  assert.equal(safePortalRedirect('https://evil.example'), '/');
  assert.equal(safePortalRedirect('//evil.example'), '/');
  assert.equal(safePortalRedirect('/\\evil.example'), '/');
  assert.equal(safePortalRedirect('/admin'), '/');
});
