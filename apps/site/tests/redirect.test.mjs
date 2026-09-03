import assert from 'node:assert/strict';
import test from 'node:test';
import { safeSiteRedirect } from '../src/domain/redirect.ts';

test('aceita somente destinos internos permitidos', () => {
  assert.equal(safeSiteRedirect('/membros?origem=login'), '/membros?origem=login');
  assert.equal(safeSiteRedirect('/'), '/');
});

test('recusa redirect externo, protocol-relative, barra invertida, controle e rota não permitida', () => {
  assert.equal(safeSiteRedirect('https://evil.example'), '/membros');
  assert.equal(safeSiteRedirect('//evil.example'), '/membros');
  assert.equal(safeSiteRedirect('/\\evil.example'), '/membros');
  assert.equal(safeSiteRedirect('/admin'), '/membros');
  assert.equal(safeSiteRedirect('/membros' + String.fromCharCode(0)), '/membros');
  assert.equal(safeSiteRedirect(undefined), '/membros');
});
