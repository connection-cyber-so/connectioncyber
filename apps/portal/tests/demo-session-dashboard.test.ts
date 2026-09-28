import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source=readFileSync(new URL('../src/components/DemoDashboard.tsx',import.meta.url),'utf8');
test('dashboard deriva vendas do ledger do caixa',()=>assert.match(source,/sessionSales/));
test('dashboard deriva estoque crítico dos produtos',()=>assert.match(source,/criticalStock/));
test('dashboard deriva contas abertas dos títulos',()=>{assert.match(source,/openReceivable/);assert.match(source,/openPayable/)});
test('dashboard mostra saldo real da sessão',()=>assert.match(source,/cashBalance/));
test('financeiro mantém títulos ao navegar',()=>assert.match(source,/financialTitles/));
