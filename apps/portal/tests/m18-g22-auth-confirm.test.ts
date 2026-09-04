import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../src/app/auth/confirm/page.tsx', import.meta.url), 'utf8');
const client = readFileSync(new URL('../src/lib/supabase/client.ts', import.meta.url), 'utf8');

test('lê o token do fragmento da URL, nunca da query string', () => {
  assert.match(page, /window\.location\.hash/);
  assert.doesNotMatch(page, /searchParams\.get\('access_token'\)/);
});

test('limpa o token da URL depois de estabelecer a sessão', () => {
  assert.match(page, /window\.history\.replaceState/);
});

test('trata error_code/otp_expired com mensagem amigável, não deixa o token vazar em erro cru', () => {
  assert.match(page, /otp_expired/);
  assert.doesNotMatch(page, /error_description/);
});

test('ativa a membership via RPC depois de definir a senha — não é automático', () => {
  assert.match(page, /\.rpc\('erp_accept_pending_memberships_v1'\)/);
});

test('client Supabase do browser é exclusivo desta página — nenhum outro lugar do portal deveria precisar dele', () => {
  assert.match(client, /createBrowserClient/);
  assert.doesNotMatch(client, /service_role/i);
});
