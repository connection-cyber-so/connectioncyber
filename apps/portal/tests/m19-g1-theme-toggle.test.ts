import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const rootLayout = readFileSync(new URL('../src/app/layout.tsx', import.meta.url), 'utf8');
const portalLayout = readFileSync(new URL('../src/app/(portal)/layout.tsx', import.meta.url), 'utf8');
const toggle = readFileSync(new URL('../src/components/ThemeToggle.tsx', import.meta.url), 'utf8');
const globals = readFileSync(new URL('../src/app/globals.css', import.meta.url), 'utf8');

test('layout raiz aplica o tema salvo antes da primeira pintura', () => {
  assert.match(rootLayout, /localStorage\.getItem\('cc-theme'\)/);
  assert.match(rootLayout, /suppressHydrationWarning/);
});

test('topbar do portal monta o ThemeToggle', () => {
  assert.match(portalLayout, /<ThemeToggle \/>/);
});

test('alternador não toca Supabase/sessão — só preferência de exibição no localStorage', () => {
  assert.doesNotMatch(toggle, /supabase|createClient|fetch\(/i);
  assert.match(toggle, /localStorage/);
});

test('paleta oficial completa (8 tons) declarada, com override explícito de tema', () => {
  for (const token of ['--orange', '--orange-alt', '--red', '--red-alt', '--green', '--green-alt', '--teal', '--teal-alt']) {
    assert.match(globals, new RegExp(`${token}:\\s*#`));
  }
  assert.match(globals, /:root\.dark\s*{/);
  assert.match(globals, /:root\.light\s*{/);
});
