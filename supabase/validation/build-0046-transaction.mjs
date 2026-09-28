import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const supabaseDirectory = path.resolve(directory, '..');
const migrationPath = path.join(supabaseDirectory, 'migrations', '0046_identity_email_alignment.sql');
const testPath = path.join(supabaseDirectory, 'tests', '0046_identity_email_alignment.test.sql');
const outputPath = path.join(directory, '0046_transaction.generated.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');
const testSuite = fs.readFileSync(testPath, 'utf8');

if (!/\nbegin;\s*/i.test(migration) || !/commit;\s*$/i.test(migration)) throw new Error('Migration 0046 is not transaction-delimited');
if (!/select plan\(4\)/i.test(testSuite)) throw new Error('M23 hygiene requires exactly 4 assertions');
if (!/^update public\.users/m.test(migration)) throw new Error('Migration 0046 must be an UPDATE of public.users only');
if (/\bdelete from\b|\btruncate\b|drop |alter |create (table|function)/i.test(migration)) throw new Error('Migration 0046 must not create or destroy objects');

const migrationBody = migration.replace(/\nbegin;\s*/i, '\n').replace(/commit;\s*$/i, '');
const testBody = testSuite
  .replace(/^begin;[\s\S]*?select plan\(4\);/i, '')
  .replace(/select\s*\*\s*from\s+finish\(\);/i, '')
  .replace(/rollback;\s*$/i, '');
const setup = "set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(4);";
const finishGate = `do $$
declare failure text;
begin
 select string_agg(result, E'\\n') into failure from finish() as f(result);
 if failure is not null then raise exception 'M23_HYGIENE_0046_PGTAP_FAILED: %',failure;end if;
end$$;
select 'M23_HYGIENE_0046_TRANSACTION_4_OF_4_ROLLBACK' as marker;`;
const generated = `begin;\n${migrationBody}\n${setup}\n${testBody}\n${finishGate}\nrollback;\n`;

if (/\bcommit\s*;/i.test(generated)) throw new Error('Generated validation contains COMMIT');
if ((generated.match(/\brollback\s*;/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one ROLLBACK');
if ((generated.match(/select plan\(/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one plan');
fs.writeFileSync(outputPath, generated, { encoding: 'utf8', flag: 'w' });
console.log(`M23_HYGIENE_0046_TRANSACTION_BUILT path=${outputPath}`);
