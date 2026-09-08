import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const layout = readFileSync(new URL('../src/app/(portal)/layout.tsx', import.meta.url), 'utf8');
const page = readFileSync(new URL('../src/app/(portal)/cadastros/page.tsx', import.meta.url), 'utf8');
const route = readFileSync(new URL('../src/app/(portal)/cadastros/nova-pessoa/route.ts', import.meta.url), 'utf8');
const writable = readFileSync(new URL('../src/features/persistence/writable.ts', import.meta.url), 'utf8');

// M21-G2 (Trilha B) — primeira tela real de cadastro do próprio cliente em apps/portal,
// mesmo rigor de teste do M19-G4 (branding): tudo por leitura de código-fonte, sem
// precisar de banco — prova a forma do código, não o comportamento em runtime.

test('menu do portal deixa de tratar Cadastros como pendente', () => {
  assert.doesNotMatch(layout, /Cadastros <small>M05<\/small>/);
  assert.match(layout, /<Link className="nav-item" href="\/cadastros">Cadastros<\/Link>/);
});

test('página de cadastros exige access authorized, nunca redireciona pra fora sem checar', () => {
  assert.match(page, /if \(access\.kind === 'not-found'\) notFound\(\);/);
  assert.match(page, /if \(access\.kind !== 'authorized'\) redirect\('\/login'\);/);
});

test('route de nova-pessoa faz same-origin check e revalida no servidor', () => {
  assert.match(route, /isSameOriginRequest/);
  assert.match(route, /status: 403/);
  assert.match(route, /isValidTaxId/);
});

test('tenant sempre vem da sessão (loadPortalAccess), nunca de input do formulário', () => {
  assert.match(writable, /access\.kind === 'authorized' \? access\.membership\.tenantId/);
  assert.doesNotMatch(route, /formData\.get\('tenant_id'\)/);
  assert.doesNotMatch(page, /searchParams\.tenant_id/);
});

test('escrita real passa pelo comando idempotente do contrato, não por insert direto', () => {
  assert.match(route, /client\.execute\('party\.create'/);
  assert.doesNotMatch(route, /\.from\('erp_parties'\)\.insert/);
});

test('nada nesta feature usa service_role — permissão sempre pela sessão do próprio usuário', () => {
  for (const source of [layout, page, route, writable]) {
    assert.doesNotMatch(source, /service_role/i);
  }
});

test('leitura de pessoas cadastradas usa o mesmo contrato de leitura (client.read), não tabela direta', () => {
  assert.match(page, /client\.read\('parties'\)/);
  assert.doesNotMatch(page, /\.from\('erp_parties'\)/);
});
