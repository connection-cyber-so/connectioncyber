import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../../../', import.meta.url);
const migration = await readFile(new URL('supabase/migrations/0044_m23_academy_foundation.sql', root), 'utf8');
const preflight = await readFile(new URL('supabase/preflight/0044_m23_academy_foundation_preflight.sql', root), 'utf8');
const rollback = await readFile(new URL('supabase/rollback/0044_m23_academy_foundation.rollback.sql', root), 'utf8');
const structural = await readFile(new URL('supabase/tests/0044_m23_academy_foundation.test.sql', root), 'utf8');
const adversarial = await readFile(new URL('supabase/tests/0044_m23_academy_foundation.adversarial.test.sql', root), 'utf8');

test('migration é transacional',()=>{assert.match(migration,/^--[\s\S]*begin;/i);assert.match(migration,/commit;\s*$/i)});
test('capacidade e permissões da academia são declaradas',()=>{assert.match(migration,/'academy\.courses'/);assert.match(migration,/'academy\.read'/);assert.match(migration,/'academy\.manage'/);assert.match(migration,/'academy\.read','Consultar Academia'/)});
test('cinco tabelas com RLS e sem DML para clientes',()=>{for(const t of ['academy_courses','academy_modules','academy_enrollments','academy_progress','academy_events'])assert.ok(migration.includes(`public.${t}`),`${t} ausente`);assert.match(migration,/enable row level security/);assert.match(migration,/revoke all on public\.%I from public,anon,authenticated/);assert.doesNotMatch(migration,/grant (insert|update|delete)[^;]*academy_/i)});
test('somente policy de leitura para clientes',()=>{const policies=migration.match(/create policy academy_\w+ on public\.academy_\w+ for select to authenticated/g)??[];assert.equal(policies.length,5);assert.doesNotMatch(migration,/for (insert|update|delete) to authenticated/i)});
test('command é security definer com search_path vazio e sem execução anônima',()=>{assert.match(migration,/create or replace function public\.academy_command[\s\S]*security definer set search_path=''/);assert.match(migration,/revoke all on function[\s\S]*public\.academy_command\(uuid,text,uuid,jsonb\) from public,anon/);assert.doesNotMatch(migration,/auth\.admin|inviteUserByEmail/i)});
test('acesso fail closed por capacidade contratada',()=>{assert.match(migration,/create or replace function erp_security\.academy_capability/);assert.match(migration,/e\.capability_key='academy\.courses'/);assert.match(migration,/x\.effect='deny'/);assert.match(migration,/erp_security\.is_tenant_member\(p_tenant\)/)});
test('gestão exige permissão explícita com nível de garantia',()=>{assert.match(migration,/has_permission_at_aal\(p_tenant,'academy\.manage','aal1'\)/)});
test('rate limit e serialização por tenant/usuário',()=>{assert.match(migration,/pg_advisory_xact_lock/);assert.match(migration,/ACADEMY_RATE_LIMIT/);assert.match(migration,/interval '1 minute'/)});
test('catálogo público legado recebe grants (R-016)',()=>{assert.match(migration,/grant select on public\.courses,public\.products,public\.cms_content to anon,authenticated/);assert.doesNotMatch(migration,/grant select on public\.orders/i)});
test('preflight é somente leitura e observa ausência',()=>{assert.match(preflight,/M23_G0_PREFLIGHT_OK/);assert.match(preflight,/migration 0044 ja aplicada/);assert.doesNotMatch(preflight,/insert into|update |delete from/i)});
test('rollback desliga comandos preservando dados',()=>{assert.match(rollback,/revoke execute on function public\.academy_command/);assert.doesNotMatch(rollback,/drop table/i)});
test('pgTAP declara 18 + 14 asserções e rollback',()=>{assert.match(structural,/select plan\(18\)/);assert.match(adversarial,/select plan\(14\)/);assert.match(structural,/select\s*\*\s*from\s+finish\(\);\s*rollback;/);assert.match(adversarial,/select\s*\*\s*from\s+finish\(\);\s*rollback;/)});
test('cenários adversariais cobrem RLS, capability e progresso',()=>{for(const s of ['ACADEMY_CURATOR_REQUIRED','ACADEMY_STATUS_INVALID','ACADEMY_COURSE_NOT_AVAILABLE','ACADEMY_ACCESS_DENIED','ACADEMY_NOT_ENROLLED'])assert.ok(adversarial.includes(s),`${s} ausente`);assert.match(adversarial,/insufficient_privilege/);assert.match(adversarial,/progresso alcanca 100/)});
test('nenhuma identidade real foi incluída nos artefatos',()=>{for(const text of[migration,preflight,rollback,structural,adversarial])assert.doesNotMatch(text,/09[.\/-]?050[.\/-]?756|@(?:gmail|hotmail|outlook|ig)\./i)});
