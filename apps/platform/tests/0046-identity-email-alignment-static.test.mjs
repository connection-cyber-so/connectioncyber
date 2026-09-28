import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../../../', import.meta.url);
const migration = await readFile(new URL('supabase/migrations/0046_identity_email_alignment.sql', root), 'utf8');
const preflight = await readFile(new URL('supabase/preflight/0046_identity_email_alignment_preflight.sql', root), 'utf8');
const rollback = await readFile(new URL('supabase/rollback/0046_identity_email_alignment.rollback.sql', root), 'utf8');
const structural = await readFile(new URL('supabase/tests/0046_identity_email_alignment.test.sql', root), 'utf8');

test('migration é transacional',()=>{assert.match(migration,/^--[\s\S]*begin;/i);assert.match(migration,/commit;\s*$/i)});
test('só alinha o e-mail, sem criar ou destruir objetos',()=>{assert.match(migration,/^update public\.users/m);assert.match(migration,/set email = lower\(a\.email\)/);assert.match(migration,/updated_at = now\(\)/);assert.doesNotMatch(migration,/delete from|truncate|drop |alter |create (table|function)/i)});
test('alvo é o Auth e há guarda contra e-mail duplicado',()=>{assert.match(migration,/from auth\.users a/);assert.match(migration,/a\.id = w\.id/);assert.match(migration,/w\.id = '61b57707-2292-49ff-8ca6-f43ccec087ed'/);assert.match(migration,/not exists \(select 1 from public\.users x where x\.email = lower\(a\.email\)\)/)});
test('preflight é somente leitura e observa a divergência',()=>{assert.match(preflight,/M23_HYGIENE_0046_PREFLIGHT_OK/);assert.match(preflight,/migration 0046 ja aplicada/);assert.match(preflight,/divergences/);assert.doesNotMatch(preflight,/update |delete from|insert into|drop |alter /i)});
test('rollback devolve o e-mail anterior sem destruir',()=>{assert.match(rollback,/update public\.users/);assert.match(rollback,/M23_HYGIENE_0046_ROLLBACK_OK/);assert.doesNotMatch(rollback,/delete from|truncate|drop /i)});
test('pgTAP declara 4 asserções e rollback',()=>{assert.match(structural,/select plan\(4\)/);assert.match(structural,/select\s*\*\s*from\s+finish\(\);\s*rollback;/);for(const s of ['identidade alinhada ao e-mail vigente do Auth','e-mail sem duplicidade em public.users','nome preservado na identidade'])assert.ok(structural.includes(s),`${s} ausente`)});
