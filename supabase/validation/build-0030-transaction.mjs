import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..','..');
const migrationPath=resolve(root,'supabase','migrations','0030_m13_fiscal_a1.sql');
const testsPath=resolve(root,'supabase','tests','0030_m13_fiscal_a1.test.sql');
const outputPath=process.argv[2];
if(!outputPath)throw new Error('output path required');
const migration=readFileSync(migrationPath,'utf8');
const tests=readFileSync(testsPath,'utf8');
const hash=createHash('sha256').update(migration).digest('hex').toUpperCase();
const expected='C88D8940AC49AF7F3EC1FA284EE1C7117DEA53E25AA3C8AA7112882141487F49';
if(hash!==expected)throw new Error(`migration hash mismatch: ${hash}`);
if(!/(^|\r?\n)begin;\s*/i.test(migration)||!/commit;\s*$/i.test(migration))throw new Error('migration boundaries invalid');
if(!/^begin;/i.test(tests)||!/rollback;\s*$/i.test(tests)||!tests.includes('select plan(100)'))throw new Error('test boundaries invalid');
const migrationBody=migration.replace(/(^|\r?\n)begin;\s*/i,'$1').replace(/commit;\s*$/i,'');
const finishGuard=`create temporary table m13_tap_results(result text) on commit drop;
insert into m13_tap_results select * from finish();
do $$begin
  if(select count(*)from m13_assertions)<>100 then raise exception 'M13_PGTAP_COUNT_INVALID: %',(select count(*)from m13_assertions);end if;
  if exists(select 1 from m13_assertions where result like 'not ok%')then raise exception 'M13_PGTAP_ASSERTION_FAILED: %',(select string_agg(result,' | ')from m13_assertions where result like 'not ok%');end if;
  if not exists(select 1 from m13_tap_results where result like '1..100%')and exists(select 1 from m13_tap_results where result ilike '%failed%')then raise exception 'M13_PGTAP_FINISH_FAILED: %',(select string_agg(result,' | ')from m13_tap_results);end if;
end$$;`;
const testsBody=tests.replace(/^begin;/i,'').replace(/select plan\(100\);/i,"select plan(100);create temporary table m13_assertions(result text)on commit drop;").replace(/select ok\(/gi,'insert into m13_assertions select ok(').replace(/select is\(/gi,'insert into m13_assertions select is(').replace(/select \* from finish\(\);/i,()=>finishGuard).replace(/rollback;\s*$/i,'');
const sql=`begin;\n${migrationBody}\n${testsBody}\nrollback;\nselect 'M13_0030_TRANSACTION_ROLLED_BACK' result;\n`;
writeFileSync(outputPath,sql,{encoding:'utf8',flag:'wx'});
console.log(JSON.stringify({result:'M13_0030_TRANSACTION_FILE_OK',hash,outputPath}));
