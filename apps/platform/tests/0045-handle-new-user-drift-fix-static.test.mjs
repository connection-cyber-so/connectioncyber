import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../../../', import.meta.url);
const migration = await readFile(new URL('supabase/migrations/0045_handle_new_user_drift_fix.sql', root), 'utf8');
const preflight = await readFile(new URL('supabase/preflight/0045_handle_new_user_drift_fix_preflight.sql', root), 'utf8');
const rollback = await readFile(new URL('supabase/rollback/0045_handle_new_user_drift_fix.rollback.sql', root), 'utf8');
const structural = await readFile(new URL('supabase/tests/0045_handle_new_user_drift_fix.test.sql', root), 'utf8');

test('migration é transacional',()=>{assert.match(migration,/^--[\s\S]*begin;/i);assert.match(migration,/commit;\s*$/i)});
test('hook volta a gravar em public.users e sai de public.profiles',()=>{assert.match(migration,/insert into public\.users \(id, nome, email, tenant_id\)/);assert.doesNotMatch(migration,/insert into public\.profiles/i);assert.match(migration,/on conflict \(id\) do nothing/)});
test('definição é a autoritativa da 0018: security definer, search_path vazio e sem fallback de tenant',()=>{assert.match(migration,/security definer\s+set search_path = ''/);assert.match(migration,/values \(new\.id, display_name, lower\(new\.email\), null\)/);assert.match(migration,/IDENTITY_EMAIL_REQUIRED/);assert.match(migration,/revoke all on function public\.handle_new_user\(\) from public, anon, authenticated/)});
test('hook de signup é garantido sem recriar trigger duplicado',()=>{assert.match(migration,/'on_auth_user_created'/);assert.match(migration,/if not exists \(\s*select 1 from pg_trigger/);assert.match(migration,/after insert on auth\.users/)});
test('backfill de identidades órfãs é idempotente e não destrutivo',()=>{assert.match(migration,/from auth\.users u/);assert.match(migration,/not exists \(select 1 from public\.users w where w\.id = u\.id\)/);assert.match(migration,/on conflict do nothing/);assert.doesNotMatch(migration,/delete from|truncate|drop table/i)});
test('preflight é somente leitura e observa o drift',()=>{assert.match(preflight,/M23_HYGIENE_0045_PREFLIGHT_OK/);assert.match(preflight,/migration 0045 ja aplicada/);assert.match(preflight,/orphans_pending/);assert.doesNotMatch(preflight,/insert into|update |delete from|create |alter |drop /i)});
test('rollback restaura a definição legada sem apagar dados',()=>{assert.match(rollback,/insert into public\.profiles/);assert.match(rollback,/M23_HYGIENE_0045_ROLLBACK_OK/);assert.doesNotMatch(rollback,/delete from|truncate|drop /i)});
test('pgTAP declara 11 asserções e rollback',()=>{assert.match(structural,/select plan\(11\)/);assert.match(structural,/select\s*\*\s*from\s+finish\(\);\s*rollback;/)});
test('cenários cobrem signup, idempotência, órfãos e privilégio',()=>{for(const s of ['IDENTITY_EMAIL_REQUIRED','nenhuma identidade orfa','hook nao grava em public.profiles','hook revogado de authenticated','backfill nao sobrescreve identidade existente'])assert.ok(structural.includes(s),`${s} ausente`)});
test('nenhuma identidade real foi incluída nos artefatos',()=>{for(const text of[migration,preflight,rollback,structural])assert.doesNotMatch(text,/09[.\/-]?050[.\/-]?756|@(?:gmail|hotmail|outlook|ig)\./i)});
