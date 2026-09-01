import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root = new URL('../../../', import.meta.url);
const migration = await readFile(new URL('supabase/migrations/0034_m18_protected_pilot_provisioning.sql', root), 'utf8');
const preflight = await readFile(new URL('supabase/preflight/0034_m18_protected_pilot_provisioning_preflight.sql', root), 'utf8');
const rollback = await readFile(new URL('supabase/rollback/0034_m18_protected_pilot_provisioning.rollback.sql', root), 'utf8');
const pgtap = await readFile(new URL('supabase/tests/0034_m18_protected_pilot_provisioning.test.sql', root), 'utf8');

test('migration é transacional',()=>{assert.match(migration,/^--[\s\S]*begin;/i);assert.match(migration,/commit;\s*$/i)});
test('inscrição estadual possui formato e unicidade tenant-scoped',()=>{assert.match(migration,/state_registration text/);assert.match(migration,/tenant_state_registration_unique/)});
test('domínio do tenant recebe unicidade case-insensitive',()=>assert.match(migration,/unique index tenants_domain_unique[\s\S]*lower\(dominio\)/i));
test('outbox e compensação são duráveis',()=>{assert.match(migration,/create table public\.erp_auth_invitation_outbox/);assert.match(migration,/create table public\.erp_auth_identity_compensations/)});
test('tabelas server-only usam RLS sem policy de cliente',()=>{assert.match(migration,/enable row level security/);assert.match(migration,/revoke all[\s\S]*authenticated/);assert.doesNotMatch(migration,/create policy/i)});
test('quatro RPCs são exclusivamente service role',()=>{assert.equal((migration.match(/create or replace function public\.erp_/g)??[]).length,4);assert.match(migration,/grant execute[\s\S]*to service_role/)});
test('prepare é idempotente e rejeita segredo',()=>{assert.match(migration,/pg_advisory_xact_lock/);assert.match(migration,/idempotency conflict/);assert.match(migration,/unsafe provisioning request/)});
test('Auth ocorre depois da transação de preparação',()=>{assert.doesNotMatch(migration,/auth\.admin|admin\.invite|inviteUserByEmail/i);assert.match(migration,/erp_record_pilot_auth_identity_v1/)});
test('finalização exige identidade Auth e profile',()=>{assert.match(migration,/exists\(select 1 from auth\.users/);assert.match(migration,/exists\(select 1 from public\.users/)});
test('owner é privilegiado e exige MFA',()=>assert.match(migration,/'owner'[\s\S]*true,true,'privileged'/));
test('compensação não exporta nem exclui identidade diretamente',()=>{assert.match(migration,/disable_then_delete/);assert.doesNotMatch(migration,/delete from auth\.users/i)});
test('preflight é read-only e observa ausência',()=>{assert.match(preflight,/begin transaction read only/);assert.match(preflight,/0034 already present/);assert.match(preflight,/rollback;/)});
test('rollback exige confirmação e tabelas vazias',()=>{assert.match(rollback,/M18_0034_EMPTY_ONLY/);assert.match(rollback,/requires empty tables/)});
test('pgTAP declara 72 asserções e rollback',()=>{assert.match(pgtap,/select plan\(72\)/);assert.match(pgtap,/select\*from finish\(\);rollback;/)});
test('nenhuma identidade real foi incluída nos artefatos',()=>{for(const text of[migration,preflight,rollback,pgtap]){assert.doesNotMatch(text,/09[.\/-]?050[.\/-]?756|@(?:gmail|hotmail|outlook|ig)\./i)}});
