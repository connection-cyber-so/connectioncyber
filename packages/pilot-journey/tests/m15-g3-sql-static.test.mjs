import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
const testSql=readFileSync(new URL('../../../supabase/tests/m15_g3_synthetic_journey.rollback.sql',import.meta.url),'utf8')
const preflight=readFileSync(new URL('../../../supabase/preflight/m15_g3_synthetic_journey_preflight.sql',import.meta.url),'utf8')
test('ensaio declara exatamente 30 asserções',()=>assert.match(testSql,/select plan\(30\)/i))
test('ensaio abre transação e termina em rollback',()=>{assert.match(testSql.trim(),/^begin;/i);assert.match(testSql.trim(),/rollback;$/i)})
test('fixtures cobrem MEI ME e LTDA',()=>{for(const profile of['synthetic-mei','synthetic-me','synthetic-ltda'])assert.match(testSql,new RegExp(profile))})
test('fixtures não criam usuário',()=>assert.doesNotMatch(testSql,/insert\s+into\s+auth\.users/i))
test('fiscal não recebe inserções',()=>assert.doesNotMatch(testSql,/insert\s+into\s+public\.erp_fiscal/i))
test('cross-tenant é exercitado em quatro domínios',()=>assert.equal((testSql.match(/select throws_ok\(/gi)||[]).length,4))
test('jornada cobre módulos operacionais',()=>{for(const table of['erp_parties','erp_catalog_items','erp_stock_movements','erp_sales','erp_cash_registers','erp_financial_entries'])assert.match(testSql,new RegExp(table))})
test('fixtures não contêm identidade fiscal',()=>{assert.doesNotMatch(testSql,/\b\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\b/);assert.doesNotMatch(testSql,/tax_id\s*[,)]\s*values/i)})
test('preflight tem marcador determinístico',()=>assert.match(preflight,/M15_G3_PREFLIGHT_OK/))
test('preflight recusa fixtures residuais',()=>assert.match(preflight,/M15_G3_STALE_FIXTURES_FOUND/))
