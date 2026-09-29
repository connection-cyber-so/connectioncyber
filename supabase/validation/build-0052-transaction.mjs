import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const supabaseDirectory = path.resolve(directory, '..');
const migrationPath = path.join(supabaseDirectory, 'migrations', '0052_m14_nfe_xml_source.sql');
const structuralPath = path.join(supabaseDirectory, 'tests', '0052_m14_nfe_xml_source.test.sql');
const outputPath = path.join(directory, '0052_transaction.generated.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');
const structural = fs.readFileSync(structuralPath, 'utf8');

if (!/\nbegin;\s*/i.test(migration) || !/commit;\s*$/i.test(migration)) throw new Error('Migration 0052 is not transaction-delimited');
if (!/select plan\(16\)/i.test(structural)) throw new Error('M14 0052 requires exactly 16 assertions');

const migrationBody = migration.replace(/\nbegin;\s*/i, '\n').replace(/commit;\s*$/i, '');
const structuralBody = structural
  .replace(/^begin;[\s\S]*?select plan\(16\);/i, '')
  .replace(/select\s*\*\s+from\s+finish\(\);/i, '')
  .replace(/rollback;\s*$/i, '');
const setup = "set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(16);";
const finishGate = `do $$
declare failure text;
begin
 select string_agg(result, E'\\n') into failure from finish() as f(result);
 if failure is not null then raise exception 'M14_0052_PGTAP_FAILED: %',failure;end if;
end$$;
select 'M14_0052_TRANSACTION_16_OF_16_ROLLBACK' as marker;`;
const generated = `begin;\n${migrationBody}\n${setup}\n${structuralBody}\n${finishGate}\nrollback;\n`;

if (/\bcommit\s*;/i.test(generated)) throw new Error('Generated validation contains COMMIT');
if ((generated.match(/\brollback\s*;/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one ROLLBACK');
if ((generated.match(/select plan\(/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one plan');
fs.writeFileSync(outputPath, generated, { encoding: 'utf8', flag: 'w' });
console.log(`M14_0052_TRANSACTION_BUILT path=${outputPath}`);
