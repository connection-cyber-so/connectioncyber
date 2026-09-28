import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const adminPage = readFileSync(
  new URL('../src/app/(portal)/academia/admin/page.tsx', import.meta.url),
  'utf8'
);
const catalog = readFileSync(
  new URL('../src/app/(portal)/academia/page.tsx', import.meta.url),
  'utf8'
);
const adminAction = readFileSync(
  new URL('../src/features/academy/admin-action.ts', import.meta.url),
  'utf8'
);
const service = readFileSync(
  new URL('../src/features/academy/service.ts', import.meta.url),
  'utf8'
);
const criarRoute = readFileSync(
  new URL('../src/app/(portal)/academia/admin/criar/route.ts', import.meta.url),
  'utf8'
);
const publicarRoute = readFileSync(
  new URL('../src/app/(portal)/academia/admin/publicar/route.ts', import.meta.url),
  'utf8'
);
const moduloRoute = readFileSync(
  new URL('../src/app/(portal)/academia/admin/modulo/route.ts', import.meta.url),
  'utf8'
);
const vincularRoute = readFileSync(
  new URL('../src/app/(portal)/academia/admin/vincular/route.ts', import.meta.url),
  'utf8'
);
const alvosRoute = readFileSync(
  new URL('../src/app/(portal)/academia/admin/alvos/route.ts', import.meta.url),
  'utf8'
);

import {
  isAcademyAction,
  parseAcademyContext,
  type AcademyContext,
} from '../src/domain/academy';

// Fatia o corpo de uma função exportada sem deixar vizinhas contaminarem o assert.
function fnBody(name: string): string {
  const marker = `export async function ${name}`;
  const start = service.indexOf(marker);
  assert.notEqual(start, -1, `função ${name} ausente do service.ts`);
  const next = service.indexOf('export async function', start + marker.length);
  return next === -1 ? service.slice(start) : service.slice(start, next);
}

// M23-G2 (porta 2) — Catálogo global + vínculo por tenant no portal. O aluno só
// enxerga curso por academy_tenant_courses (RLS 0048); o gestor cura tudo via
// public.academy_command; staff é o único que mexe em alvo/escopo global.

test('catálogo do aluno resolve por vínculo ativo, nunca por tenant do curso', () => {
  assert.match(service, /export async function listLinkedCourseIds/);
  const linked = fnBody('listLinkedCourseIds');
  assert.match(linked, /\.from\('academy_tenant_courses'\)/);
  assert.match(linked, /\.eq\('tenant_id', tenantId\)/);
  assert.match(linked, /\.eq\('ativo', true\)/);
  const listPublished = fnBody('listPublishedCourses');
  assert.match(listPublished, /\.in\('id', linked\)/);
  assert.doesNotMatch(listPublished, /\.eq\('tenant_id', tenantId\)/);
  const loadCourseBody = fnBody('loadCourse');
  assert.match(loadCourseBody, /listLinkedCourseIds\(supabase, tenantId\)/);
  assert.match(loadCourseBody, /if \(!linked\.includes\(courseId\)\) return null;/);
});

test('módulos são lidos por course_id — global mora no tenant dono', () => {
  const listModules = fnBody('listModules');
  assert.match(listModules, /\.eq\('course_id', courseId\)/);
  assert.doesNotMatch(listModules, /\.eq\('tenant_id'/);
});

test('curadoria lê o global pela RLS de descoberta (select + policy, sem RPC)', () => {
  assert.match(service, /export async function listGlobalCatalog/);
  assert.match(service, /\.eq\('escopo', 'global'\)/);
  assert.doesNotMatch(service, /rpc\('academy_global_catalog'/);
  assert.match(service, /export async function listCuratorCatalog/);
});

test('página do catálogo só abre para gestor (access + manage) e não vaza tenant', () => {
  assert.match(adminPage, /if \(access\.kind === 'not-found'\) notFound\(\);/);
  assert.match(adminPage, /if \(access\.kind !== 'authorized'\) redirect\('\/login'\);/);
  assert.match(adminPage, /if \(!context\.access \|\| !context\.manage\)/);
  assert.match(adminPage, /access\.membership\.tenantId/);
  assert.doesNotMatch(adminPage, /formData\.get\('tenant_id'\)/);
  assert.doesNotMatch(adminPage, /searchParams\.tenant_id/);
});

test('toda escrita da curadoria passa por public.academy_command, nunca insert direto', () => {
  for (const source of [adminPage, adminAction, service, criarRoute, publicarRoute, moduloRoute, vincularRoute, alvosRoute]) {
    assert.doesNotMatch(source, /\.from\('academy_\w+'\)\s*\.\s*(insert|update|delete)/);
  }
  assert.match(adminAction, /runAcademyCommand/);
  assert.match(criarRoute, /action: 'create_course'/);
  assert.match(publicarRoute, /action: 'publish_course'/);
  assert.match(moduloRoute, /action: 'add_module'/);
  assert.match(vincularRoute, /link_course/);
  assert.match(vincularRoute, /unlink_course/);
  assert.match(alvosRoute, /action: 'set_course_targets'/);
});

test('ação de curadoria faz same-origin, valida UUID e só passa allowlist de campos', () => {
  assert.match(adminAction, /isSameOriginRequest/);
  assert.match(adminAction, /status: 403/);
  assert.match(adminAction, /isUuid\(rawCourseId\)/);
  assert.match(adminAction, /courseRequired !== false && !courseId/);
  assert.match(adminAction, /options\.fields \?\? \[\]/);
  assert.match(adminAction, /tenantId: access\.membership\.tenantId/);
  assert.doesNotMatch(adminAction, /formData\.get\('tenant_id'\)/);
  assert.doesNotMatch(adminAction, /formData\.get\('role'\)/);
});

test('create_course é a única ação sem curso; alvos aceitam campo vazio para limpar', () => {
  assert.match(criarRoute, /courseRequired: false/);
  assert.match(publicarRoute, /fields: \['status'\]/);
  assert.match(moduloRoute, /fields: \['titulo', 'tipo', 'conteudo_ref', 'duracao_min'\]/);
  assert.match(alvosRoute, /emptyOk: \['alvo_sistema', 'alvo_vertical'\]/);
  for (const route of [publicarRoute, moduloRoute, vincularRoute, alvosRoute]) {
    assert.doesNotMatch(route, /courseRequired: false/);
  }
});

test('aluno não cura: página de catálogo é link só para manage e ações do G1 seguem intactas', () => {
  assert.match(catalog, /\{context\.manage \? \(/);
  assert.match(catalog, /href="\/academia\/admin">Catálogo</);
});

test('ações e erros novos do G2 existem no domínio (fail-closed inclui staff)', () => {
  for (const action of [
    'create_course',
    'publish_course',
    'add_module',
    'link_course',
    'unlink_course',
    'set_course_targets',
  ]) {
    assert.equal(isAcademyAction(action), true);
  }
  assert.equal(isAcademyAction('set_alvos_global'), false);
  const staffOnly: AcademyContext = parseAcademyContext({ staff: 'yes' });
  assert.equal(staffOnly.staff, false);
  assert.equal(parseAcademyContext({ staff: true }).staff, true);
  assert.equal(parseAcademyContext(null).staff, false);
});
