#!/usr/bin/env node
// M15-G12 - materializacao de entidades (parties, catalogo, vendas) a partir da fonte NF-e.
// Uso: node scripts/m15-materialize-entities.mjs --config <config.json> [--dry-run]
// Reusa o mesmo config do M14-G9. SQL com dado real sai em %TEMP% (fora do repo).
// Idempotencia por id deterministico (sha256) + ON CONFLICT DO UPDATE.
import{readFileSync,writeFileSync,statSync,readdirSync,mkdirSync}from'node:fs';
import{createHash}from'node:crypto';
import{spawnSync}from'node:child_process';
import{tmpdir}from'node:os';
import path from'node:path';
import{fileURLToPath}from'node:url';
import{classifyNfeDocument,parseNfeDocument,uuidFromSha256}from'../packages/import-contract/src/nfe-adapter.mjs';

const sha256=value=>createHash('sha256').update(value).digest('hex');
const repoRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
const arg=name=>{const index=args.indexOf(name);return index>=0?args[index+1]:null};
const die=message=>{console.error(`[ERRO] ${message}`);process.exit(1)};
const configPath=arg('--config');
if(!configPath)die('uso: node scripts/m15-materialize-entities.mjs --config <config.json> [--dry-run]');
const dryRun=args.includes('--dry-run');
const workDir=path.join(tmpdir(),'connectioncyber-m15');
mkdirSync(workDir,{recursive:true});
const config=JSON.parse(readFileSync(path.resolve(configPath),'utf8'));

const q=v=>`'${String(v).replace(/'/g,"''")}'`;
const num=v=>Number.isFinite(v)?v:0;
const clamp=(v,min,max)=>{let s=String(v??'').trim();while(s.length<min)s+='_';return s.slice(0,max)};
const T01={'01':'DIN','03':'CRE','04':'DEB','15':'PIX'};
const SEED_UNITS=[['UN','Unidade','count',0],['KG','Quilograma','mass',3],['CX','Caixa','count',0]];
const SEED_METHODS=[['DIN','Dinheiro','cash'],['PIX','PIX','pix'],['CRE','Cartao de credito','credit_card'],['DEB','Cartao de debito','debit_card'],['OUT','Outro','other']];

function walk(dir,out=[]){for(const entry of readdirSync(dir,{withFileTypes:true})){const full=path.join(dir,entry.name);if(entry.isDirectory())walk(full,out);else if(entry.isFile()&&entry.name.toLowerCase().endsWith('.xml'))out.push(full)}return out}

export function buildMaterializationPlan(tenantId,documents){
  const stats={documents:0,authorized:0,sales:0,items:0,payments:0,parties:0,catalog:0,skippedItems:0,skippedPayments:0,buyersAnon:0};
  const parties=new Map(),catalog=new Map(),sales=[];
  const byChave=new Map();
  for(const document of documents){
    stats.documents++;
    if(classifyNfeDocument(document.content)!=='authorized')continue;
    stats.authorized++;
    const invoice=parseNfeDocument(document.content);
    if(!byChave.has(invoice.chave))byChave.set(invoice.chave,invoice);
  }
  const sorted=[...byChave.values()].sort((a,b)=>a.chave<b.chave?-1:1);
  for(const invoice of sorted){
    const buyerDoc=invoice.buyer?.document??'';
    let customerId=null;
    if(buyerDoc){
      const kind=buyerDoc.length===14?'organization':'person';
      const key=uuidFromSha256(sha256(`${tenantId}|party|${buyerDoc}`));
      customerId=key;
      if(!parties.has(key))parties.set(key,{id:key,tax_id:buyerDoc,kind,legal_name:clamp(invoice.buyer.name||buyerDoc,2,180)});
      stats.parties=parties.size;
    }else stats.buyersAnon++;
    for(const item of invoice.items){
      const catalogId=uuidFromSha256(sha256(`${tenantId}|item|${item.code??''}`));
      if(!catalog.has(catalogId))catalog.set(catalogId,{id:catalogId,code:clamp(item.code,1,64),name:clamp(item.name||item.code,2,180)});
    }
    const saleId=uuidFromSha256(sha256(`${tenantId}|sale|${invoice.chave}`));
    const sale={id:saleId,code:`NFE-${invoice.chave}`,idempotency_key:`m15-nfe-${invoice.chave}`,customer_id:customerId,status:invoice.emittedAt?'completed':'draft',completed_at:invoice.emittedAt??null,subtotal:num(invoice.totals.productsCents)/100,discount_total:num(invoice.totals.discountCents)/100,grand_total:num(invoice.totals.totalCents)/100,items:[],payments:[]};
    invoice.items.forEach((item,index)=>{
      const quantity=num(Number.parseFloat(item.qty));
      if(!(quantity>0)||!item.code){stats.skippedItems++;return}
      sale.items.push({id:uuidFromSha256(sha256(`${tenantId}|saleitem|${invoice.chave}|${index}`)),item_id:uuidFromSha256(sha256(`${tenantId}|item|${item.code??''}`)),code:clamp(item.code,1,64),description:clamp(item.name||item.code,2,180),quantity,unit_price:Number.isFinite(item.unitPrice)?item.unitPrice:num(item.unitPriceCents)/100,line_total:num(item.amountCents)/100});
    });
    invoice.payments.forEach((payment,index)=>{
      const amount=num(payment.amountCents)/100;
      if(!(amount>0)){stats.skippedPayments++;return}
      const method=T01[payment.method]??'OUT';
      sale.payments.push({id:uuidFromSha256(sha256(`${tenantId}|paytxn|${invoice.chave}|${index}`)),idempotency_key:`m15-nfe-${invoice.chave}-p${index}`,external_id:`${invoice.chave}-p${index}`,method,amount,captured_at:invoice.emittedAt??null});
    });
    sales.push(sale);
    stats.sales++;
    stats.items+=sale.items.length;
    stats.payments+=sale.payments.length;
  }
  stats.parties=parties.size;
  stats.catalog=catalog.size;
  return{parties:[...parties.values()],catalog:[...catalog.values()],sales,stats};
}

function buildSql(tenantId,establishmentId,plan){
  const parts=['begin;',"select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);"];
  parts.push(`insert into public.erp_units(id,tenant_id,code,name,dimension,decimal_scale) values${SEED_UNITS.map(([code,name,dimension,scale])=>`(${q(uuidFromSha256(sha256(`${tenantId}|unit|${code}`)))},${q(tenantId)},${q(code)},${q(name)},${q(dimension)},${scale})`).join(',')} on conflict (id) do update set name=excluded.name,active=true;`);
  parts.push(`insert into public.erp_payment_methods(id,tenant_id,code,name,kind) values${SEED_METHODS.map(([code,name,kind])=>`(${q(uuidFromSha256(sha256(`${tenantId}|pay|${code}`)))},${q(tenantId)},${q(code)},${q(name)},${q(kind)})`).join(',')} on conflict (id) do update set name=excluded.name,kind=excluded.kind;`);
  if(plan.parties.length){
    parts.push(`insert into public.erp_parties(id,tenant_id,kind,legal_name,tax_id) values${plan.parties.map(p=>`(${q(p.id)},${q(tenantId)},${q(p.kind)},${q(p.legal_name)},${q(p.tax_id)})`).join(',')} on conflict (id) do update set legal_name=excluded.legal_name,tax_id=excluded.tax_id,active=true;`);
    parts.push(`insert into public.erp_party_roles(tenant_id,party_id,role,active) values${plan.parties.map(p=>`(${q(tenantId)},${q(p.id)},'customer',true)`).join(',')} on conflict (tenant_id,party_id,role) do update set active=true;`);
  }
  if(plan.catalog.length){
    const unit=(tenantId,code)=>uuidFromSha256(sha256(`${tenantId}|unit|${code}`));
    parts.push(`insert into public.erp_catalog_items(id,tenant_id,kind,code,name,base_unit_id,status,track_inventory) values${plan.catalog.map(i=>`(${q(i.id)},${q(tenantId)},'product',${q(i.code)},${q(i.name)},${q(unit(tenantId,'UN'))},'active',false)`).join(',')} on conflict (id) do update set name=excluded.name,status='active';`);
  }
  if(plan.sales.length){
    parts.push(`insert into public.erp_sales(id,tenant_id,establishment_id,customer_id,code,status,completed_at,subtotal,discount_total,grand_total,idempotency_key) values${plan.sales.map(s=>`(${q(s.id)},${q(tenantId)},${q(establishmentId)},${s.customer_id?q(s.customer_id):'null'},${q(s.code)},${q(s.status)},${s.completed_at?q(s.completed_at):'null'},${s.subtotal},${s.discount_total},${s.grand_total},${q(s.idempotency_key)})`).join(',')} on conflict (id) do update set status=excluded.status,completed_at=excluded.completed_at,subtotal=excluded.subtotal,discount_total=excluded.discount_total,grand_total=excluded.grand_total;`);
    const itemRows=plan.sales.flatMap(s=>s.items.map(i=>`(${q(i.id)},${q(tenantId)},${q(s.id)},${q(i.item_id)},${q(uuidFromSha256(sha256(`${tenantId}|unit|UN`)))},${q(i.code)},${q(i.description)},${i.quantity},${i.unit_price},${i.line_total})`));
    if(itemRows.length)parts.push(`insert into public.erp_sale_items(id,tenant_id,sale_id,item_id,unit_id,item_code_snapshot,description_snapshot,quantity,unit_price,line_total) values${itemRows.join(',')} on conflict (id) do update set quantity=excluded.quantity,unit_price=excluded.unit_price,line_total=excluded.line_total;`);
    const payRows=plan.sales.flatMap(s=>s.payments.map(p=>`(${q(p.id)},${q(tenantId)},${q(s.id)},${q(uuidFromSha256(sha256(`${tenantId}|pay|${p.method}`)))},${p.amount},'${p.captured_at?'captured':'pending'}',${p.captured_at?q(p.captured_at):'null'},'nfe_xml',${q(p.external_id)},${q(p.idempotency_key)})`));
    if(payRows.length)parts.push(`insert into public.erp_sale_payments(id,tenant_id,sale_id,payment_method_id,amount,status,captured_at,provider,external_id,idempotency_key) values${payRows.join(',')} on conflict (id) do update set amount=excluded.amount;`);
  }
  parts.push(`select 'M15_MAT_SUMMARY' as marcador,(select count(*) from public.erp_parties where tenant_id='${tenantId}') as parties,(select count(*) from public.erp_catalog_items where tenant_id='${tenantId}') as catalogo,(select count(*) from public.erp_sales where tenant_id='${tenantId}') as vendas,(select count(*) from public.erp_sale_items where tenant_id='${tenantId}') as itens,(select count(*) from public.erp_sale_payments where tenant_id='${tenantId}') as pagamentos,(select coalesce(round(sum(grand_total)*100)::bigint,0) from public.erp_sales where tenant_id='${tenantId}') as valor_cents,(select count(*) from public.erp_import_items i join public.erp_import_batches b on b.id=i.batch_id where i.tenant_id='${tenantId}' and b.domain='sales') as vendas_ledger,(select coalesce(sum(i.source_amount_cents),0) from public.erp_import_items i join public.erp_import_batches b on b.id=i.batch_id where i.tenant_id='${tenantId}' and b.domain='sales') as ledger_cents;`);
  parts.push('commit;');
  return parts.join('\n')+'\n';
}

function parseSummary(stdout){
  if(!/"marcador"\s*:\s*"M15_MAT_SUMMARY"/.test(stdout))return null;
  const field=name=>{const found=stdout.match(new RegExp(`"${name}"\\s*:\\s*"?(-?[0-9]+)"?`));return found?Number(found[1]):null};
  return Object.fromEntries(['parties','catalogo','vendas','itens','pagamentos','valor_cents','vendas_ledger','ledger_cents'].map(name=>[name,field(name)]));
}

function runSql(sqlFile){
  if(sqlFile.includes(' '))die('caminho do SQL contem espaco');
  const run=spawnSync('supabase',['db','query','--linked','-f',sqlFile],{cwd:repoRoot,encoding:'utf8',shell:process.platform==='win32',timeout:600000,maxBuffer:16*1024*1024});
  const stdout=`${run.stdout??''}\n${run.stderr??''}`;
  if(run.status!==0)die(`supabase db query falhou (status ${run.status})\n${stdout.slice(-3000)}`);
  return stdout;
}

const results=[];
for(const tenant of config.tenants){
  if(!tenant.slug||!tenant.tenantId||!tenant.expectedCnpj||!tenant.root)die(`config incompleto para ${tenant.slug??tenant.root}`);
  console.log(`[INFO] ${tenant.slug}: materializando...`);
  const files=walk(path.resolve(tenant.root));
  const documents=files.map(file=>({content:readFileSync(file,'utf8')}));
  const plan=buildMaterializationPlan(tenant.tenantId,documents);
  if(plan.stats.sales===0)die(`${tenant.slug}: nenhuma NF-e autorizada`);
  const estabFile=path.join(workDir,`estab-${tenant.slug}.sql`);
  writeFileSync(estabFile,`select id from public.erp_establishments where tenant_id='${tenant.tenantId}' and active order by created_at limit 1;\n`,'utf8');
  const estabRun=spawnSync('supabase',['db','query','--linked','-f',estabFile],{cwd:repoRoot,encoding:'utf8',shell:process.platform==='win32',timeout:120000,maxBuffer:4*1024*1024});
  const estabOut=`${estabRun.stdout??''}`;
  const estabMatch=estabOut.match(/"id"\s*:\s*"([0-9a-f-]{36})"/);
  if(estabRun.status!==0||!estabMatch)die(`${tenant.slug}: sem estabelecimento ativo\n${estabOut.slice(-1000)}`);
  const establishmentId=estabMatch[1];
  const stamp=new Date().toISOString().replace(/[:.]/g,'-');
  const sqlFile=path.join(workDir,`mat-${tenant.slug}-${stamp}.sql`);
  writeFileSync(sqlFile,buildSql(tenant.tenantId,establishmentId,plan),'utf8');
  let summary=null;
  if(!dryRun){
    summary=parseSummary(runSql(sqlFile));
    if(!summary)die(`${tenant.slug}: resumo M15_MAT_SUMMARY ausente`);
    const checks=[
      ['vendas',summary.vendas,summary.vendas_ledger],
      ['valor_cents',summary.valor_cents,summary.ledger_cents],
      ['catalogo',summary.catalogo,plan.stats.catalog]
    ];
    for(const[label,materializado,esperado]of checks)if(materializado!==esperado)die(`${tenant.slug}: reconciliacao ${label} materializado=${materializado} esperado=${esperado}`);
  }
  results.push({tenant:tenant.slug,stats:plan.stats,ledger:summary,sqlFile});
  console.log(`[OK] ${tenant.slug}: ${plan.stats.sales} vendas, ${plan.stats.items} itens, ${plan.stats.parties} parties, ${plan.stats.catalog} produtos${dryRun?' (dry-run)':''}`);
}
const summaryFile=path.join(workDir,`materialize-summary-${new Date().toISOString().replace(/[:.]/g,'-')}.json`);
writeFileSync(summaryFile,JSON.stringify(results,null,2),'utf8');
console.log(`[OK] resumo geral: ${summaryFile}`);
