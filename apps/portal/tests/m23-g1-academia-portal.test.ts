import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const layout = readFileSync(new URL('../src/app/(portal)/layout.tsx', import.meta.url), 'utf8');
const catalog = readFileSync(new URL('../src/app/(portal)/academia/page.tsx', import.meta.url), 'utf8');
const course = readFileSync(new URL('../src/app/(portal)/academia/[courseId]/page.tsx', import.meta.url), 'utf8');
const formAction = readFileSync(new URL('../src/features/academy/form-action.ts', import.meta.url), 'utf8');
const service = readFileSync(new URL('../src/features/academy/service.ts', import.meta.url), 'utf8');
const enrollRoute = readFileSync(new URL('../src/app/(portal)/academia/matricular/route.ts', import.meta.url), 'utf8');
const completeRoute = readFileSync(new URL('../src/app/(portal)/academia/concluir-modulo/route.ts', import.meta.url), 'utf8');

import {
  academyErrorMessage,
  canCompleteModule,
  canEnroll,
  formatProgress,
  isAcademyAction,
  isUuid,
  parseAcademyContext,
} from '../src/domain/academy';

// M23-G1 (porta 1) — Academia no portal do cliente: catálogo, matrícula e progresso
// consumindo a fundação da 0044. Mesmo rigor do M21-G2/M19-G4: leitura de código
// prova a forma, o domínio puro prova a regra.

test('menu do portal só mostra Academia com acesso real, senão fica como pendente', () => {
  assert.match(layout, /\{academy\.access \? \(/);
  assert.match(layout, /<Link className="nav-item" href="\/academia">Academia<\/Link>/);
  assert.match(layout, /<span className="nav-item pending">Academia <small>M23<\/small><\/span>/);
  assert.match(layout, /loadAcademyContext\(supabase, access\.membership\.tenantId\)/);
});

test('páginas exigem membership authorized e não vazam sem checar', () => {
  for (const page of [catalog, course]) {
    assert.match(page, /if \(access\.kind === 'not-found'\) notFound\(\);/);
    assert.match(page, /if \(access\.kind !== 'authorized'\) redirect\('\/login'\);/);
  }
  assert.match(course, /if \(!context\.access\) notFound\(\);/);
});

test('toda escrita da Academia passa por public.academy_command, nunca insert/update direto', () => {
  assert.match(service, /supabase\.rpc\('academy_command'/);
  assert.match(formAction, /runAcademyCommand/);
  assert.match(enrollRoute, /action: 'enroll'/);
  assert.match(completeRoute, /action: 'complete_module'/);
  for (const source of [catalog, course, service, formAction]) {
    assert.doesNotMatch(source, /\.from\('academy_\w+'\)\s*\.\s*(insert|update|delete)/);
  }
});

test('rota de escrita faz same-origin e valida UUID antes de chamar o comando', () => {
  assert.match(formAction, /isSameOriginRequest/);
  assert.match(formAction, /status: 403/);
  assert.match(formAction, /isUuid\(rawCourseId\)/);
  assert.match(formAction, /options\.requireModule && !isUuid\(rawModuleId\)/);
  assert.doesNotMatch(formAction, /formData\.get\('tenant_id'\)/);
});

test('tenant sempre vem da membership autorizada, nunca do formulário', () => {
  assert.match(formAction, /tenantId: access\.membership\.tenantId/);
  assert.match(catalog, /access\.membership\.tenantId/);
  assert.doesNotMatch(course, /searchParams\.tenant_id/);
  assert.doesNotMatch(catalog, /formData\.get\('tenant_id'\)/);
});

test('contexto da Academia é fail-closed em payload malformado', () => {
  assert.deepEqual(parseAcademyContext(null), {
    access: false,
    manage: false,
    capability: false,
    staff: false,
  });
  assert.deepEqual(parseAcademyContext({ access: 'yes' }), {
    access: false,
    manage: false,
    capability: false,
    staff: false,
  });
  assert.deepEqual(
    parseAcademyContext({ access: true, manage: true, capability: true, staff: true }),
    {
      access: true,
      manage: true,
      capability: true,
      staff: true,
    }
  );
});

test('matrícula exige acesso + curso publicado e não repete matrícula ativa', () => {
  const context = { access: true, manage: false, capability: true, staff: false };
  assert.equal(canEnroll({ context, courseStatus: 'publicado', enrollment: null }), true);
  assert.equal(canEnroll({ context, courseStatus: 'rascunho', enrollment: null }), false);
  assert.equal(
    canEnroll({ context, courseStatus: 'publicado', enrollment: { course_id: 'x', status: 'ativa', progresso: 10, concluida_em: null } }),
    false
  );
  assert.equal(
    canEnroll({ context, courseStatus: 'publicado', enrollment: { course_id: 'x', status: 'cancelada', progresso: 0, concluida_em: null } }),
    true
  );
  assert.equal(canEnroll({ context: { access: false, manage: false, capability: false, staff: false }, courseStatus: 'publicado', enrollment: null }), false);
});

test('conclusão de módulo só aparece com matrícula ativa e módulo pendente', () => {
  const context = { access: true, manage: false, capability: true, staff: false };
  const ativa = { course_id: 'x', status: 'ativa' as const, progresso: 50, concluida_em: null };
  assert.equal(canCompleteModule({ context, enrollment: ativa, moduleDone: false }), true);
  assert.equal(canCompleteModule({ context, enrollment: ativa, moduleDone: true }), false);
  assert.equal(
    canCompleteModule({ context, enrollment: { course_id: 'x', status: 'concluida', progresso: 100, concluida_em: '2026-09-27' }, moduleDone: false }),
    false
  );
  assert.equal(canCompleteModule({ context, enrollment: null, moduleDone: false }), false);
});

test('helpers de UI não inventam valor: progresso clampado, ação e UUID estritos', () => {
  assert.equal(formatProgress(-5), '0%');
  assert.equal(formatProgress(120), '100%');
  assert.equal(formatProgress(37.4), '37%');
  assert.equal(formatProgress('x'), '0%');
  assert.equal(isAcademyAction('enroll'), true);
  assert.equal(isAcademyAction('drop_all'), false);
  assert.equal(isUuid('61b57707-2292-49ff-8ca6-f43ccec087ed'), true);
  assert.equal(isUuid('61b57707-2292-49ff-8ca6'), false);
  assert.equal(academyErrorMessage('ACADEMY_ACCESS_DENIED').includes('acesso'), true);
  assert.equal(academyErrorMessage('QUALQUER_COISA').includes('Não foi possível'), true);
});
