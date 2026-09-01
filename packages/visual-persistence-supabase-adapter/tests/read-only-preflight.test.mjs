import test from'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';
const sql=readFileSync(new URL('../../../supabase/preflight/m18_g8_visual_read_only_preflight.sql',import.meta.url),'utf8');
test('preflight abre transação somente leitura e termina em rollback',()=>{assert.match(sql,/begin;\s*set transaction read only;/i);assert.match(sql,/rollback;\s*$/i);});
test('preflight não contém comandos mutáveis',()=>assert.doesNotMatch(sql,/\b(insert|update|delete|merge|truncate|alter|create|drop|grant|revoke)\b/i));
test('preflight verifica as sete RPCs persistentes',()=>assert.equal(new Set(sql.match(/erp_command_[a-z_]+_v1\(uuid,text,text,jsonb\)/g)).size,7));
test('preflight verifica RLS das relações lidas',()=>assert.match(sql,/relrowsecurity/));
test('preflight compara authenticated e anon',()=>{assert.match(sql,/has_table_privilege\('authenticated'/);assert.match(sql,/has_table_privilege\('anon'/);assert.match(sql,/has_function_privilege\('authenticated'/);assert.match(sql,/has_function_privilege\('anon'/);});
test('preflight declara marcador determinístico',()=>assert.match(sql,/M18_G8_READ_ONLY_PREFLIGHT_OK/));
