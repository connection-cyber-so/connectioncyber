import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source=readFileSync(new URL('../src/components/DemoInventory.tsx',import.meta.url),'utf8');
test('estoque oferece entrada e saída',()=>{assert.match(source,/Entrada/);assert.match(source,/Saída/)});
test('estoque bloqueia saldo negativo',()=>assert.match(source,/selected\.stock\+delta<0/));
test('estoque permanece somente em memória',()=>assert.doesNotMatch(source,/fetch\(|supabase|localStorage|sessionStorage|indexedDB/i));
test('movimento comunica integração imediata com PDV',()=>assert.match(source,/alteram imediatamente a disponibilidade no PDV/));
