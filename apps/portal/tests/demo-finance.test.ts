import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source=readFileSync(new URL('../src/components/DemoFinance.tsx',import.meta.url),'utf8');
test('financeiro cobre pagar receber e baixa',()=>{for(const marker of['Pagar','Receber','Dar baixa'])assert.match(source,new RegExp(marker))});
test('baixa exige caixa aberto',()=>assert.match(source,/if\(!cashOpen\)/));
test('pagamento bloqueia saldo insuficiente',()=>assert.match(source,/title\.amount>cashBalance/));
test('baixa reflete entrada ou saída no caixa',()=>assert.match(source,/onCashMovement/));
test('financeiro não usa persistência',()=>assert.doesNotMatch(source,/fetch\(|supabase|localStorage|sessionStorage|indexedDB/i));
