import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../../../', import.meta.url);
const migration = await readFile(new URL('supabase/migrations/0047_sync_auth_email_trigger.sql', root), 'utf8');
const preflight = await readFile(new URL('supabase/preflight/0047_sync_auth_email_trigger_preflight.sql', root), 'utf8');
const rollback = await readFile(new URL('supabase/rollback/0047_sync_auth_email_trigger.rollback.sql', root), 'utf8');
const structural = await readFile(new URL('supabase/tests/0047_sync_auth_email_trigger.test.sql', root), 'utf8');

test('migration é transacional',()=>{assert.match(migration,/^--[\s\S]*begin;/i);assert.match(migration,/commit;\s*$/i)});
test('função de sincronismo é security definer com search_path vazio e sem execução anônima',()=>{assert.match(migration,/create or replace function public\.sync_auth_email\(\)/);assert.match(migration,/security definer\s+set search_path = ''/);assert.match(migration,/revoke all on function public\.sync_auth_email\(\) from public, anon, authenticated/);assert.doesNotMatch(migration,/auth\.admin|inviteUserByEmail/i)});
test('trigger dispara só em troca de e-mail',()=>{assert.match(migration,/create trigger on_auth_user_email_changed/);assert.match(migration,/after update of email on auth\.users/);assert.match(migration,/when \(old\.email is distinct from new\.email\)/);assert.match(migration,/execute function public\.sync_auth_email\(\)/)});
test('sincronismo preserva a identidade e normaliza o e-mail',()=>{assert.match(migration,/values \(new\.id, display_name, lower\(new\.email\), null\)/);assert.match(migration,/on conflict \(id\) do update/);assert.match(migration,/where w\.email is distinct from excluded\.email/);assert.match(migration,/if new\.email is null or btrim\(new\.email\) = '' then/);assert.doesNotMatch(migration,/delete from|truncate|drop table/i)});
test('preflight é somente leitura e observa o estado prévio',()=>{assert.match(preflight,/M23_HYGIENE_0047_PREFLIGHT_OK/);assert.match(preflight,/migration 0047 ja aplicada/);assert.match(preflight,/trigger_present/);assert.doesNotMatch(preflight,/insert into|update |delete from|create |drop /i)});
test('rollback remove apenas os objetos criados',()=>{assert.match(rollback,/drop trigger if exists on_auth_user_email_changed/);assert.match(rollback,/drop function if exists public\.sync_auth_email\(\)/);assert.match(rollback,/M23_HYGIENE_0047_ROLLBACK_OK/);assert.doesNotMatch(rollback,/delete from|truncate|drop table/i)});
test('pgTAP declara 7 asserções e rollback',()=>{assert.match(structural,/select plan\(7\)/);assert.match(structural,/select\s*\*\s*from\s+finish\(\);\s*rollback;/);for(const s of ['troca de e-mail no Auth propaga em minusculas','identidade ausente e recriada com o e-mail novo','e-mail nulo no Auth nao apaga a identidade'])assert.ok(structural.includes(s),`${s} ausente`)});
