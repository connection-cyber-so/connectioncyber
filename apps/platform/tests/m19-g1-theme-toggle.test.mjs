import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const rootLayout = readFileSync(new URL('../src/app/layout.tsx', import.meta.url), 'utf8');
const painelLayout = readFileSync(new URL('../src/app/(painel)/layout.tsx', import.meta.url), 'utf8');
const toggle = readFileSync(new URL('../src/components/ThemeToggle.tsx', import.meta.url), 'utf8');
const theme = readFileSync(new URL('../src/styles/theme.css', import.meta.url), 'utf8');

test('layout raiz aplica o tema salvo antes da primeira pintura', () => {
  assert.match(rootLayout, /localStorage\.getItem\('cc-theme'\)/);
  assert.match(rootLayout, /suppressHydrationWarning/);
});

test('topbar do painel monta o ThemeToggle', () => {
  assert.match(painelLayout, /<ThemeToggle \/>/);
});

test('alternador não toca Supabase/sessão — só preferência de exibição no localStorage', () => {
  assert.doesNotMatch(toggle, /supabase|createClient|fetch\(/i);
  assert.match(toggle, /localStorage/);
});

test('tema explícito (.dark/.light) sempre vence a preferência do sistema', () => {
  assert.match(theme, /:root\.dark\s*{/);
  assert.match(theme, /:root\.light\s*{/);
  assert.match(theme, /prefers-color-scheme:\s*dark\)\s*{\s*:root:not\(\.light\)/);
});
