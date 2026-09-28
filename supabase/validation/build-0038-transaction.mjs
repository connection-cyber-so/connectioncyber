import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const supabaseDirectory = path.resolve(directory, '..');
const migrationPath = path.join(supabaseDirectory, 'migrations', '0038_m20_business_verticals.sql');
const structuralPath = path.join(supabaseDirectory, 'tests', '0038_m20_business_verticals.test.sql');
const adversarialPath = path.join(supabaseDirectory, 'tests', '0038_m20_business_verticals.adversarial.test.sql');
const outputPath = path.join(directory, '0038_transaction.generated.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');
const structural = fs.readFileSync(structuralPath, 'utf8');
const adversarial = fs.readFileSync(adversarialPath, 'utf8');

if (!/\nbegin;\s*/i.test(migration) || !/commit;\s*$/i.test(migration)) throw new Error('Migration 0038 is not transaction-delimited');
if (!/select plan\(20\)/i.test(structural) || !/select plan\(9\)/i.test(adversarial)) throw new Error('M20-G2 requires exactly 20 + 9 assertions');

const migrationBody = migration.replace(/\nbegin;\s*/i, '\n').replace(/commit;\s*$/i, '');
const stripTest = (sql, plan) => sql
  .replace(new RegExp(`^begin;[\\s\\S]*?select plan\\(${plan}\\);`, 'i'), '')
  .replace(/select\s*\*\s*from\s+finish\(\);/i, '')
  .replace(/rollback;\s*$/i, '');
const structuralBody = stripTest(structural, 20);
const adversarialBody = stripTest(adversarial, 9);
const setup = "set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(29);";
const finishGate = `do $$
declare failure text;
begin
 select string_agg(result, E'\\n') into failure from finish() as f(result);
 if failure is not null then raise exception 'M20_0038_PGTAP_FAILED: %',failure;end if;
end$$;
select 'M20_0038_TRANSACTION_29_OF_29_ROLLBACK' as marker;`;
const generated = `begin;\n${migrationBody}\n${setup}\n${structuralBody}\n${adversarialBody}\n${finishGate}\nrollback;\n`;

if (/\bcommit\s*;/i.test(generated)) throw new Error('Generated validation contains COMMIT');
if ((generated.match(/\brollback\s*;/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one ROLLBACK');
if ((generated.match(/select plan\(/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one plan');
fs.writeFileSync(outputPath, generated, { encoding: 'utf8', flag: 'w' });
console.log(`M20_0038_TRANSACTION_BUILT path=${outputPath}`);
