import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../src/app/(portal)/cadastros/page.tsx', import.meta.url), 'utf8');
const css = readFileSync(new URL('../src/app/(portal)/cadastros/cadastros.css', import.meta.url), 'utf8');
const docRoute = readFileSync(new URL('../src/app/(portal)/cadastros/novo-documento/route.ts', import.meta.url), 'utf8');
const contactRoute = readFileSync(new URL('../src/app/(portal)/cadastros/novo-contato/route.ts', import.meta.url), 'utf8');
const addressRoute = readFileSync(new URL('../src/app/(portal)/cadastros/novo-endereco/route.ts', import.meta.url), 'utf8');

// M21-G3 — a tela real de Cadastros passa a seguir o mesmo layout validado em
// cadastros-tela-unica.html (5 rodadas de PDF confirmadas com o usuário): header-bar
// com contador, campos agrupados, painel lateral com abas de Documentos/Contatos/
// Endereços — não mais o formulário genérico do design system padrão do portal.

test('CSS reaproveita a paleta oficial do layout validado (#0A1F33 nas bordas de campo)', () => {
  assert.match(css, /--cc-blue-900:#0a1f33/);
  assert.match(css, /border:1\.5px solid var\(--cc-blue-900\)/);
});

test('página usa a estrutura header-bar/counter-row/body-grid/side-tabs do layout validado', () => {
  assert.match(page, /className="header-bar"/);
  assert.match(page, /className="counter-row"/);
  assert.match(page, /className="body-grid"/);
  assert.match(page, /className="side-tabs"/);
  assert.match(page, /className="extra-tabs"/);
});

test('nenhum handler de evento é passado como string (bug real de JSX corrigido)', () => {
  assert.doesNotMatch(page, /onInput="/);
  assert.doesNotMatch(page, /onBlur="/);
  assert.doesNotMatch(page, /onClick="/);
});

test('máscara/validação de documento é ligada via addEventListener, não atributo inline', () => {
  assert.match(page, /addEventListener\('input',function\(\)\{ccMaskDoc\(doc\)\}\)/);
  assert.match(page, /addEventListener\('blur',function\(\)\{ccCheckDoc\(doc\)\}\)/);
});

test('painel de documentos/contatos/endereços só aparece com uma pessoa selecionada', () => {
  assert.match(page, /selectedParty \? \(/);
});

for (const [name, route] of [['novo-documento', docRoute], ['novo-contato', contactRoute], ['novo-endereco', addressRoute]] as const) {
  test(`route ${name} faz same-origin check e revalida no servidor`, () => {
    assert.match(route, /isSameOriginRequest/);
    assert.match(route, /status: 403/);
  });
  test(`route ${name}: tenant sempre vem da sessão, nunca de input do formulário`, () => {
    assert.doesNotMatch(route, /formData\.get\('tenant_id'\)/);
    assert.match(route, /loadPortalAccess/);
  });
  test(`route ${name}: nada usa service_role`, () => {
    assert.doesNotMatch(route, /service_role/i);
  });
}

test('novo-documento escreve pelo comando idempotente party.document.add', () => {
  assert.match(docRoute, /client\.execute\('party\.document\.add'/);
});
test('novo-contato escreve pelo comando idempotente party.contact.add', () => {
  assert.match(contactRoute, /client\.execute\('party\.contact\.add'/);
});
test('novo-endereco escreve pelo comando idempotente party.address.add', () => {
  assert.match(addressRoute, /client\.execute\('party\.address\.add'/);
});
