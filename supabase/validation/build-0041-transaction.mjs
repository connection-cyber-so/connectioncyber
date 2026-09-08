import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const supabaseDirectory = path.resolve(directory, '..');
const migrationPath = path.join(supabaseDirectory, 'migrations', '0041_m21_g2_backfill_owner_permissions.sql');
const structuralPath = path.join(supabaseDirectory, 'tests', '0041_m21_g2_backfill_owner_permissions.test.sql');
const adversarialPath = path.join(supabaseDirectory, 'tests', '0041_m21_g2_backfill_owner_permissions.adversarial.test.sql');
const outputPath = path.join(directory, '0041_transaction.generated.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');
const structural = fs.readFileSync(structuralPath, 'utf8');
const adversarial = fs.readFileSync(adversarialPath, 'utf8');

if (!/\nbegin;\s*/i.test(migration) || !/commit;\s*$/i.test(migration)) throw new Error('Migration 0041 is not transaction-delimited');
if (!/select plan\(4\)/i.test(structural) || !/select plan\(5\)/i.test(adversarial)) throw new Error('M21-G2 requires exactly 4 + 5 assertions');

const migrationBody = migration.replace(/\nbegin;\s*/i, '\n').replace(/commit;\s*$/i, '');
const stripTest = (sql, plan) => sql
  .replace(new RegExp(`^begin;[\\s\\S]*?select plan\\(${plan}\\);`, 'i'), '')
  .replace(/select\s*\*\s*from\s+finish\(\);/i, '')
  .replace(/rollback;\s*$/i, '');
const structuralBody = stripTest(structural, 4);
const adversarialBody = stripTest(adversarial, 5);
const setup = "set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(9);";
const finishGate = `do $$
declare failure text;
begin
 select string_agg(result, E'\\n') into failure from finish() as f(result);
 if failure is not null then raise exception 'M21_G2_0041_PGTAP_FAILED: %',failure;end if;
end$$;
select 'M21_G2_0041_TRANSACTION_9_OF_9_ROLLBACK' as marker;`;
const generated = `begin;\n${migrationBody}\n${setup}\n${structuralBody}\n${adversarialBody}\n${finishGate}\nrollback;\n`;

if (/\bcommit\s*;/i.test(generated)) throw new Error('Generated validation contains COMMIT');
if ((generated.match(/\brollback\s*;/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one ROLLBACK');
if ((generated.match(/select plan\(/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one plan');
fs.writeFileSync(outputPath, generated, { encoding: 'utf8', flag: 'w' });
console.log(`M21_G2_0041_TRANSACTION_BUILT path=${outputPath}`);
