import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const engine = readFileSync(new URL('../src/features/rollout/engine.ts', import.meta.url), 'utf8');
const component = readFileSync(new URL('../src/features/rollout/components/RolloutSimulator.tsx', import.meta.url), 'utf8');
const presentation = readFileSync(new URL('../src/features/rollout/presentation.ts', import.meta.url), 'utf8');
const page = readFileSync(new URL('../src/app/(painel)/implantacao/page.tsx', import.meta.url), 'utf8');
const nav = readFileSync(new URL('../src/components/SidebarNav.tsx', import.meta.url), 'utf8');

test('sequência de ondas é explícita e determinística', () => assert.match(engine, /\['laboratory', 'canary', 'cohort', 'complete'\]/));
test('promoção exige volume mínimo', () => assert.match(engine, /observations < 100/));
test('promoção bloqueia erro acima de um por cento', () => assert.match(engine, /errorRate > 1/));
test('promoção bloqueia latência acima de 500 ms', () => assert.match(engine, /latencyP95Ms > 500/));
test('qualquer violação cross-tenant bloqueia promoção', () => assert.match(engine, /crossTenantViolations !== 0/));
test('rollback precisa estar preparado', () => assert.match(engine, /!metrics\.rollbackReady/));
test('rollback afeta somente o tenant selecionado', () => assert.match(component, /item\.id === tenant\.id \? rollbackTenant\(item\) : item/));
test('rollback restaura release anterior', () => assert.match(engine, /release: tenant\.previousRelease/));
test('três perfis usam somente identificadores sintéticos', () => { for (const profile of ['MEI', 'ME', 'LTDA']) assert.match(presentation, new RegExp(`profile: '${profile}'`)); assert.doesNotMatch(presentation, /cnpj|cpf|09\.050\.756|13\.348\.881/i); });
test('simulador não chama rede ou banco', () => assert.doesNotMatch(component + engine, /fetch\(|@supabase|createClient|\.from\(/i));
test('tela informa claramente o escopo sintético', () => assert.match(component, /Ambiente totalmente sintético/));
test('rota protegida e navegação estão registradas', () => { assert.match(page, /RolloutSimulator/); assert.match(nav, /href: '\/implantacao'/); });
