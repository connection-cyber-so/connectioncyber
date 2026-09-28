import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const directory = path.dirname(fileURLToPath(import.meta.url));
const testsPath = path.resolve(directory, '..', 'tests', '0031_m14_import_ledger.test.sql');
const outputPath = path.join(directory, '0031_postapply.generated.sql');
const tests = fs.readFileSync(testsPath, 'utf8');

if (!/^begin;/i.test(tests) || !/select plan\(96\)/i.test(tests) || !/rollback;\s*$/i.test(tests)) {
  throw new Error('pgTAP 0031 boundaries or plan are invalid');
}

const body = tests
  .replace(/^begin;/i, '')
  .replace(/select \* from finish\(\);/i, '')
  .replace(/rollback;\s*$/i, '');
const finishGate = `do $$
declare failure text;
begin
 select string_agg(result, E'\\n') into failure from finish() as f(result);
 if failure is not null then raise exception 'M14_0031_PGTAP_FAILED: %', failure;end if;
end$$;
select 'M14_0031_POSTAPPLY_96_OF_96_ROLLBACK' result;`;

fs.writeFileSync(outputPath, `begin;\n${body}\n${finishGate}\nrollback;\n`, 'utf8');
console.log(`M14_0031_POSTAPPLY_BUILT path=${outputPath}`);
