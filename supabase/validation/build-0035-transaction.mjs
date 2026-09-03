import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const supabaseDirectory = path.resolve(directory, '..');
const migrationPath = path.join(supabaseDirectory, 'migrations', '0035_m19_tenant_branding.sql');
const testsPath = path.join(supabaseDirectory, 'tests', '0035_m19_tenant_branding.test.sql');
const outputPath = path.join(directory, '0035_transaction.generated.sql');
const migration = fs.readFileSync(migrationPath, 'utf8');
const tests = fs.readFileSync(testsPath, 'utf8');

if (!/\nbegin;\s*/i.test(migration) || !/commit;\s*$/i.test(migration)) throw new Error('Migration 0035 is not transaction-delimited');
if (!/^begin;/i.test(tests) || !/rollback;\s*$/i.test(tests)) throw new Error('pgTAP 0035 is not rollback-delimited');
if (!/select plan\(16\)/i.test(tests)) throw new Error('pgTAP 0035 must declare exactly 16 assertions');

const migrationBody = migration.replace(/\nbegin;\s*/i, '\n').replace(/commit;\s*$/i, '');
const testsBody = tests.replace(/^begin;/i, '').replace(/select\s*\*\s*from\s+finish\(\);/i, '').replace(/rollback;\s*$/i, '');
const finishGate = `do $$
declare failure text;
begin
 select string_agg(result, E'\\n') into failure from finish() as f(result);
 if failure is not null then raise exception 'M19_0035_PGTAP_FAILED: %', failure;end if;
end$$;
select 'M19_0035_TRANSACTION_16_OF_16_ROLLBACK' result;`;
const generated = `begin;\n${migrationBody}\n${testsBody}\n${finishGate}\nrollback;\n`;

if (/\bcommit\s*;/i.test(generated)) throw new Error('Generated validation contains COMMIT');
if ((generated.match(/\brollback\s*;/gi) ?? []).length !== 1) throw new Error('Generated validation must contain exactly one ROLLBACK');
fs.writeFileSync(outputPath, generated, { encoding: 'utf8', flag: 'w' });
console.log(`M19_0035_TRANSACTION_BUILT path=${outputPath}`);
