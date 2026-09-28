import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..','..');
const migration=readFileSync(resolve(root,'supabase','migrations','0030_m13_fiscal_a1.sql'),'utf8');
const tests=readFileSync(resolve(root,'supabase','tests','0030_m13_fiscal_a1.test.sql'),'utf8');
const outputPath=process.argv[2];
const hash=createHash('sha256').update(migration).digest('hex').toUpperCase();
if(hash!=='C88D8940AC49AF7F3EC1FA284EE1C7117DEA53E25AA3C8AA7112882141487F49')throw new Error(`migration hash mismatch: ${hash}`);
if(!outputPath||!/^begin;/i.test(tests)||!/rollback;\s*$/i.test(tests)||!tests.includes('select plan(100)'))throw new Error('post-apply test boundaries invalid');
const guard=`create temporary table m13_tap_finish(result text)on commit drop;
insert into m13_tap_finish select * from finish();
do $$begin
  if(select count(*)from m13_assertions)<>100 then raise exception 'M13_PGTAP_COUNT_INVALID: %',(select count(*)from m13_assertions);end if;
  if exists(select 1 from m13_assertions where result like 'not ok%')then raise exception 'M13_PGTAP_ASSERTION_FAILED: %',(select string_agg(result,' | ')from m13_assertions where result like 'not ok%');end if;
  if exists(select 1 from m13_tap_finish where result ilike '%failed%')then raise exception 'M13_PGTAP_FINISH_FAILED: %',(select string_agg(result,' | ')from m13_tap_finish);end if;
end$$;`;
const body=tests.replace(/select plan\(100\);/i,"select plan(100);create temporary table m13_assertions(result text)on commit drop;").replace(/select ok\(/gi,'insert into m13_assertions select ok(').replace(/select is\(/gi,'insert into m13_assertions select is(').replace(/select \* from finish\(\);/i,()=>guard).replace(/rollback;\s*$/i,"rollback;select 'M13_0030_POSTAPPLY_100_OK' result;");
writeFileSync(outputPath,body,{encoding:'utf8',flag:'wx'});
console.log(JSON.stringify({result:'M13_0030_POSTAPPLY_FILE_OK',hash,outputPath}));
