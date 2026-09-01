import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { persistentVisualTransportEnabled, selectVisualPersistence } from '../src/features/persistence/selector.mjs';

const root = new URL('../src/', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const selected = read('features/persistence/selected.ts');
const screenPaths = [
  'app/(painel)/page.tsx', 'app/(painel)/cadastros/page.tsx', 'app/(painel)/catalogo/page.tsx',
  'app/(painel)/operacoes/page.tsx', 'app/(painel)/pdv/page.tsx', 'app/(painel)/financeiro/page.tsx',
  'features/parties/actions.ts', 'features/catalog/actions.ts', 'features/operations/actions.ts',
  'features/sales/actions.ts', 'features/finance/actions.ts'
];
const screens = screenPaths.map(read).join('\n');

test('dublê sintético é selecionado sem acesso remoto', () => {
  const facade = Object.freeze({ marker: 'double' });
  const result = selectVisualPersistence({ mode: 'synthetic', synthetic: facade });
  assert.equal(result.facade, facade);
  assert.equal(result.remote, false);
  assert.equal(persistentVisualTransportEnabled, false);
});

test('modo persistente falha fechado antes de tocar o dublê', () => {
  let touched = false;
  const persistent = Object.defineProperty({}, 'client', { get() { touched = true; return {}; } });
  assert.throws(() => selectVisualPersistence({ mode: 'persistent', persistent }), error => error.code === 'PERSISTENT_TRANSPORT_DISABLED');
  assert.equal(touched, false);
});

test('modo ausente ou desconhecido é recusado', () => {
  assert.throws(() => selectVisualPersistence(), error => error.code === 'PERSISTENCE_MODE_INVALID');
  assert.throws(() => selectVisualPersistence({ mode: 'auto', synthetic: {} }), error => error.code === 'PERSISTENCE_MODE_INVALID');
});

test('dublê sintético ausente é recusado', () => {
  assert.throws(() => selectVisualPersistence({ mode: 'synthetic' }), error => error.code === 'SYNTHETIC_TRANSPORT_UNAVAILABLE');
});

test('fachada selecionada fixa modo sintético sem ambiente ou Supabase', () => {
  assert.match(selected, /mode: 'synthetic'/);
  assert.doesNotMatch(selected, /process\.env|createClient|features\/persistence\/persistent/);
  assert.match(selected, /transporte remoto desativado/);
});

test('todas as telas e ações usam somente a fachada selecionada', () => {
  assert.match(screens, /features\/persistence\/selected/);
  assert.doesNotMatch(screens, /features\/persistence\/(local|persistent)/);
  assert.doesNotMatch(screens, /createClient|@supabase\/supabase-js/);
});
