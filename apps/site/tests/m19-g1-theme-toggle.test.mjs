import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const document = readFileSync(new URL('../src/pages/_document.tsx', import.meta.url), 'utf8');
const header = readFileSync(new URL('../src/components/Header.tsx', import.meta.url), 'utf8');
const toggle = readFileSync(new URL('../src/components/ThemeToggle.tsx', import.meta.url), 'utf8');
const theme = readFileSync(new URL('../src/styles/theme.css', import.meta.url), 'utf8');

test('_document aplica o tema salvo antes da primeira pintura', () => {
  assert.match(document, /localStorage\.getItem\('cc-theme'\)/);
});

test('header monta o ThemeToggle', () => {
  assert.match(header, /<ThemeToggle \/>/);
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
