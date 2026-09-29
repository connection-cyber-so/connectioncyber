#!/usr/bin/env node
// M15-G13 - estoque por tenant: local real por estabelecimento ativo + rastreio ativo
// no catalogo. Nao cria saldo inicial: saldo real exige contagem fisica na operacao
// (M15-G15); inventar quantidade seria dado falso.
// Uso: node scripts/m15-stock-bootstrap.mjs [--dry-run]
import{writeFileSync,mkdirSync}from'node:fs';
import{createHash}from'node:crypto';
import{spawnSync}from'node:child_process';
import{tmpdir}from'node:os';
import path from'node:path';
import{fileURLToPath}from'node:url';
import{uuidFromSha256}from'../packages/import-contract/src/nfe-adapter.mjs';

const sha256=value=>createHash('sha256').update(value).digest('hex');
const repoRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const dryRun=process.argv.includes('--dry-run');
const workDir=path.join(tmpdir(),'connectioncyber-m15');
mkdirSync(workDir,{recursive:true});
const q=v=>`'${String(v).replace(/'/g,"''")}'`;

function runSql(sqlFile){
  if(sqlFile.includes(' '))throw new Error('caminho do SQL contem espaco');
  const run=spawnSync('supabase',['db','query','--linked','-f',sqlFile],{cwd:repoRoot,encoding:'utf8',shell:process.platform==='win32',timeout:600000,maxBuffer:16*1024*1024});
  const stdout=`${run.stdout??''}\n${run.stderr??''}`;
  if(run.status!==0)throw new Error(`supabase db query falhou (status ${run.status})\n${stdout.slice(-3000)}`);
  return stdout;
}

const estabQuery=`select concat(tenant_id,'|',id,'|',code,'|',coalesce(trade_name,legal_name)) as linha from public.erp_establishments where active order by tenant_id, created_at;\n`;
const estabFile=path.join(workDir,'stock-estabs.sql');
writeFileSync(estabFile,estabQuery,'utf8');
const estabOut=runSql(estabFile);
const estabs=[...estabOut.matchAll(/"linha"\s*:\s*"([^"]+)"/g)].map(match=>{
  const[tenant_id,establishment_id,code,name]=match[1].split('|');
  if(!tenant_id||!establishment_id||!code)throw new Error(`linha de estabelecimento invalida: ${match[1]}`);
  return{tenant_id,establishment_id,code,name:name||code};
});
if(!estabs.length)throw new Error('nenhum estabelecimento ativo encontrado');
console.log(`[INFO] ${estabs.length} estabelecimentos ativos em ${new Set(estabs.map(e=>e.tenant_id)).size} tenants`);

const seen=new Set();
const rows=estabs.map(e=>{
  if(seen.has(`${e.tenant_id}|${e.code}`))throw new Error(`code de estabelecimento duplicado no tenant: ${e.code}`);
  seen.add(`${e.tenant_id}|${e.code}`);
  return`(${q(uuidFromSha256(sha256(`${e.tenant_id}|${e.establishment_id}|stock-location`)))},${q(e.tenant_id)},${q(e.establishment_id)},${q(e.code)},${q(e.name)})`;
});
const ids=estabs.map(e=>q(uuidFromSha256(sha256(`${e.tenant_id}|${e.establishment_id}|stock-location`))));
const sql=[
  'begin;',
  "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);",
  `insert into public.erp_stock_locations(id,tenant_id,establishment_id,code,name) values${rows.join(',')} on conflict (id) do update set name=excluded.name,active=true;`,
  "update public.erp_catalog_items set track_inventory=true where kind='product' and track_inventory is distinct from true;",
  `select 'M15_STOCK_SUMMARY' as marcador,(select count(*) from public.erp_stock_locations where id in (${ids.join(',')})) as locais,(select count(*) from public.erp_catalog_items where track_inventory) as rastreados;`,
  'commit;',
  ''
].join('\n');
const stamp=new Date().toISOString().replace(/[:.]/g,'-');
const sqlFile=path.join(workDir,`stock-${stamp}.sql`);
writeFileSync(sqlFile,sql,'utf8');
if(dryRun){
  console.log(`[OK] dry-run: ${sqlFile}`);
  process.exit(0);
}
const out=runSql(sqlFile);
if(!/"marcador"\s*:\s*"M15_STOCK_SUMMARY"/.test(out))throw new Error('resumo M15_STOCK_SUMMARY ausente');
const field=name=>{const found=out.match(new RegExp(`"${name}"\\s*:\\s*"?([0-9]+)"?`));return found?Number(found[1]):null};
const locais=field('locais'),rastreados=field('rastreados');
if(locais!==estabs.length)throw new Error(`reconciliacao locais: banco=${locais} esperado=${estabs.length}`);
if(rastreados===null||rastreados<1)throw new Error('nenhum produto com rastreio ativo');
console.log(`[OK] locais=${locais} (1 por estabelecimento), produtos rastreados=${rastreados}`);
console.log(`[OK] SQL executado: ${sqlFile}`);
