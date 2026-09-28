import assert from 'node:assert/strict';
import test from 'node:test';
import { classifyPortalHostname, normalizeHostname } from '../src/domain/hostname.ts';

const options = {
  centralHostnames: ['portal.connectioncyber.com.br'],
  allowLocalhost: true,
};

test('normaliza caixa, porta e ponto final', () => {
  assert.equal(normalizeHostname(' Cliente.ConnectionCyber.com.br:3021. '), null);
  assert.equal(
    normalizeHostname(' Cliente.ConnectionCyber.com.br:3021 '),
    'cliente.connectioncyber.com.br'
  );
  assert.equal(
    normalizeHostname('CLIENTE.CONNECTIONCYBER.COM.BR.'),
    'cliente.connectioncyber.com.br'
  );
});

test('recusa wildcard, caminho, IP arbitrário e labels inválidos', () => {
  assert.equal(normalizeHostname('*.connectioncyber.com.br'), null);
  assert.equal(normalizeHostname('cliente.connectioncyber.com.br/login'), null);
  assert.equal(normalizeHostname('192.168.0.20'), null);
  assert.equal(normalizeHostname('-cliente.connectioncyber.com.br'), null);
});

test('reconhece somente hosts centrais exatos', () => {
  assert.equal(classifyPortalHostname('portal.connectioncyber.com.br', options).kind, 'central');
  assert.equal(
    classifyPortalHostname('portal.connectioncyber.com.br.evil.test', options).kind,
    'tenant-candidate'
  );
});

test('localhost é central apenas quando explicitamente permitido', () => {
  assert.equal(classifyPortalHostname('localhost:3021', options).kind, 'central');
  assert.equal(
    classifyPortalHostname('localhost:3021', { ...options, allowLocalhost: false }).kind,
    'invalid'
  );
});

test('domínio sintaticamente válido depende de resolução exata no banco', () => {
  assert.deepEqual(classifyPortalHostname('loja.exemplo.com.br', options), {
    kind: 'tenant-candidate',
    hostname: 'loja.exemplo.com.br',
  });
});
