import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { resolveVisualPersistenceMode, selectVisualPersistence } from '../src/features/persistence/selector.mjs';

const selected = readFileSync(new URL('../src/features/persistence/selected.ts', import.meta.url), 'utf8');
const envExample = readFileSync(new URL('../.env.local.example', import.meta.url), 'utf8');
const validation = readFileSync(new URL('../../../supabase/validation/m18_g12_persistent_read_only.sql', import.meta.url), 'utf8');

test('flag server-side aceita somente sintético e persistente read-only', () => {
  assert.equal(resolveVisualPersistenceMode(), 'synthetic');
  assert.equal(resolveVisualPersistenceMode('synthetic'), 'synthetic');
  assert.equal(resolveVisualPersistenceMode('persistent-read-only'), 'persistent-read-only');
  for (const value of ['persistent', 'remote', 'true', 'production']) assert.throws(() => resolveVisualPersistenceMode(value), error => error.code === 'PERSISTENCE_MODE_INVALID');
});

test('seleção read-only declara remoto sem escrita', () => {
  const facade = Object.freeze({ read: true });
  const result = selectVisualPersistence({ mode: 'persistent-read-only', persistentReadOnly: facade });
  assert.equal(result.facade, facade);
  assert.equal(result.remote, true);
  assert.equal(result.writes, false);
});

test('modo read-only sem fachada falha fechado', () => {
  assert.throws(() => selectVisualPersistence({ mode: 'persistent-read-only' }), error => error.code === 'PERSISTENT_READ_ONLY_TRANSPORT_UNAVAILABLE');
});

test('comandos são bloqueados antes da criação do cliente persistente', () => {
  const block = selected.indexOf('async execute(command: CommandName)');
  const read = selected.indexOf('async read(model: ReadModelName)', block);
  const client = selected.indexOf('async function persistentClient()');
  assert.ok(block >= 0 && block < read && read < client);
  assert.match(selected, /CAPABILITY_REQUIRED/);
  assert.doesNotMatch(selected.slice(block, read), /createClient|persistentClient\(/);
});

test('leituras persistentes derivam sessão e tenant no servidor', () => {
  assert.match(selected, /createClient\(\)/);
  assert.match(selected, /resolveTenant: getCurrentTenantId/);
  assert.doesNotMatch(selected, /serviceRole|service_role|SUPABASE_SECRET/);
});

test('flag não é pública nem possui modo de escrita', () => {
  assert.match(envExample, /SERVER_VISUAL_PERSISTENCE_MODE=synthetic/);
  assert.doesNotMatch(envExample, /NEXT_PUBLIC_VISUAL_PERSISTENCE_MODE/);
  assert.match(envExample, /synthetic \| persistent-read-only/);
});

test('validação remota é somente leitura e não chama RPC', () => {
  assert.match(validation, /begin transaction read only/i);
  assert.match(validation, /rollback;/i);
  assert.match(validation, /M18_G12_PERSISTENT_READ_ONLY_OK/);
  assert.doesNotMatch(validation, /\b(insert|update|delete|merge|truncate|alter|create|drop|grant|revoke)\b/i);
  assert.doesNotMatch(validation, /select\s+public\.erp_command_/i);
});
