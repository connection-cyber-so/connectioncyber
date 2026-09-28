import assert from 'node:assert/strict';
import test from 'node:test';
import { isSameOriginRequest } from '../src/domain/request-origin.ts';

test('aceita POST originado no mesmo protocolo, host e porta', () => {
  assert.equal(
    isSameOriginRequest('http://localhost:3021', 'http://localhost:3021/auth/login'),
    true
  );
  assert.equal(
    isSameOriginRequest(
      'https://portal.connectioncyber.com.br',
      'https://portal.connectioncyber.com.br/auth/logout'
    ),
    true
  );
});

test('recusa origem ausente, malformada, externa ou com porta diferente', () => {
  assert.equal(isSameOriginRequest(null, 'https://portal.connectioncyber.com.br'), false);
  assert.equal(isSameOriginRequest('not-a-url', 'https://portal.connectioncyber.com.br'), false);
  assert.equal(
    isSameOriginRequest('https://evil.example', 'https://portal.connectioncyber.com.br'),
    false
  );
  assert.equal(
    isSameOriginRequest('http://localhost:3022', 'http://localhost:3021'),
    false
  );
});
