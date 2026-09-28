import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const treinamentoPage = readFileSync(
  new URL('../src/app/(portal)/treinamento/page.tsx', import.meta.url),
  'utf8'
);
const academiaPage = readFileSync(
  new URL('../src/app/(portal)/academia/page.tsx', import.meta.url),
  'utf8'
);
const layout = readFileSync(
  new URL('../src/app/(portal)/layout.tsx', import.meta.url),
  'utf8'
);
const service = readFileSync(
  new URL('../src/features/academy/service.ts', import.meta.url),
  'utf8'
);

// Fatia o corpo de uma função exportada sem deixar vizinhas contaminarem o assert.
function fnBody(name: string): string {
  const marker = `export async function ${name}`;
  const start = service.indexOf(marker);
  assert.notEqual(start, -1, `função ${name} ausente do service.ts`);
  const next = service.indexOf('export async function', start + marker.length);
  return next === -1 ? service.slice(start) : service.slice(start, next);
}

// M23-G3 (porta 2) — Treinamento agrupa o catálogo da empresa pela origem do alvo:
// "do seu sistema" (alvo_sistema do curso) vs "gerais". Leitura pura pela mesma RLS
// da 0048; sem capacidade a página fecha com o mesmo fail-closed da Academia.

test('treinamento resolve por vínculo, só publicado, e agrupa pelo alvo', () => {
  assert.match(service, /export async function listTrainingCourses/);
  const training = fnBody('listTrainingCourses');
  assert.match(training, /listLinkedCourseIds\(supabase, tenantId\)/);
  assert.match(training, /\.in\('id', linked\)/);
  assert.match(training, /\.eq\('status', 'publicado'\)/);
  assert.match(training, /alvo_sistema !== null/);
  assert.match(training, /alvo_sistema === null/);
  assert.doesNotMatch(training, /\.eq\('tenant_id', tenantId\)/);
});

test('página do treinamento é leitura pura com as mesmas portas da Academia', () => {
  assert.match(treinamentoPage, /if \(access\.kind === 'not-found'\) notFound\(\);/);
  assert.match(treinamentoPage, /if \(access\.kind !== 'authorized'\) redirect\('\/login'\);/);
  assert.match(treinamentoPage, /loadAcademyContext\(supabase, tenantId\)/);
  assert.match(treinamentoPage, /listTrainingCourses\(supabase, tenantId\)/);
  assert.match(treinamentoPage, />Do seu sistema</);
  assert.match(treinamentoPage, />Gerais</);
  assert.match(treinamentoPage, /href=\{`\/academia\/\$\{course\.id\}`\}/);
  assert.doesNotMatch(treinamentoPage, /\.from\('academy_\w+'\)\s*\.\s*(insert|update|delete)/);
  assert.doesNotMatch(treinamentoPage, /academia\/matricular/);
});

test('sem capacidade o treinamento fecha com o mesmo aviso da Academia', () => {
  assert.match(treinamentoPage, /Treinamento indisponível para \{access\.membership\.tenantName\}/);
  assert.match(treinamentoPage, /academy\.courses não está contratada/);
  assert.match(treinamentoPage, /A conta não tem permissão|Sua conta não tem permissão/);
});

test('navegação: sidebar e Academia expõem o Treinamento só com acesso', () => {
  assert.match(layout, /href="\/treinamento">Treinamento</);
  assert.match(layout, /academy\.access \? \(/);
  assert.match(academiaPage, /href="\/treinamento">Treinamento</);
  assert.match(academiaPage, /\{context\.access \? \(/);
});
