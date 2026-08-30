import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../src/components/DemoDashboard.tsx', import.meta.url), 'utf8');

test('demonstração cobre MEI ME e LTDA', () => {
  for (const profile of ['MEI', 'ME', 'LTDA']) assert.match(source, new RegExp(`${profile}:`));
});
test('demonstração é explicitamente sintética e local', () => {
  assert.match(source, /DEMONSTRAÇÃO LOCAL/);
  assert.match(source, /Nenhum dado real/);
  assert.match(source, /sem conexão com produção/);
});
test('navegação cobre módulos essenciais', () => {
  for (const module of ['cadastros', 'estoque', 'vendas', 'caixa', 'financeiro']) assert.match(source, new RegExp(`key:'${module}'`));
});
test('componente não usa cliente Supabase ou fetch', () => {
  assert.doesNotMatch(source, /supabase|fetch\(|XMLHttpRequest/i);
});
test('perfil MEI mantém estoque indisponível', () => {
  const mei = source.match(/MEI:\{[^}]+enabled:\[([^\]]+)\]/)?.[1] ?? '';
  assert.doesNotMatch(mei, /estoque/);
});
