#!/usr/bin/env node
// M14 - carga real de NF-e (nfe-xml) no ledger de importacao do staging.
// Uso: node scripts/m14-import-nfe.mjs --config <config.json> [--dry-run]
// O config traz por tenant: slug, tenantId, expectedCnpj, root.
// Todo SQL gerado com dado real fica fora do repo (diretorio temporario).
import{readFileSync,writeFileSync,statSync,readdirSync,mkdirSync}from'node:fs';
import{createHash}from'node:crypto';
import{spawnSync}from'node:child_process';
import{tmpdir}from'node:os';
import path from'node:path';
import{fileURLToPath}from'node:url';
import{classifyNfeDocument,parseNfeDocument,planImport,uuidFromSha256}from'../packages/import-contract/src/nfe-adapter.mjs';
import{validateSourceManifest,canonicalHash}from'../packages/import-contract/src/index.mjs';

const sha256=value=>createHash('sha256').update(value).digest('hex');
const repoRoot=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
const arg=name=>{const index=args.indexOf(name);return index>=0?args[index+1]:null};
const die=message=>{console.error(`[ERRO] ${message}`);process.exit(1)};
const configPath=arg('--config');
if(!configPath)die('uso: node scripts/m14-import-nfe.mjs --config <config.json> [--dry-run]');
const dryRun=args.includes('--dry-run');
const workDir=path.join(tmpdir(),'connectioncyber-m14');
mkdirSync(workDir,{recursive:true});
const config=JSON.parse(readFileSync(path.resolve(configPath),'utf8'));
const schemaVersion=config.schemaVersion??'legacy-sicnet-nfe-v1';

function walk(dir,out=[]){for(const entry of readdirSync(dir,{withFileTypes:true})){const full=path.join(dir,entry.name);if(entry.isDirectory())walk(full,out);else if(entry.isFile()&&entry.name.toLowerCase().endsWith('.xml'))out.push(full)}return out}
const sqlLiteral=value=>String(value).replace(/'/g,"''");

function buildLoadSql(tenant,manifest,plan,notesHash,keys){
  const tenantId=tenant.tenantId,idem=keys.idempotencyKey,jobIdem=keys.jobKey;
  const totalRecords=plan.batches.reduce((sum,batch)=>sum+batch.records.length,0);
  const totalAmount=plan.batches.reduce((sum,batch)=>sum+batch.expectedMetrics.amountCents,0);
  const metadata=JSON.stringify({source_system:'SICNET',source_version:'1.0',export_format:'nfe-xml',notes_hash:notesHash});
  const lines=['begin;',"select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);",'do $m14_load$',`declare v_tenant uuid := '${tenantId}';v_manifest uuid;v_job uuid;v_batch uuid;`,'begin',
    `  v_manifest := public.erp_register_import_manifest(v_tenant,'${sqlLiteral(idem)}','nfe_xml','${manifest.sourceSha256}','${sqlLiteral(schemaVersion)}','${manifest.capturedAt}','${metadata}'::jsonb);`,
    "  update public.erp_import_manifests set status='validated' where tenant_id=v_tenant and id=v_manifest;",
    `  v_job := public.erp_open_import_job(v_tenant,v_manifest,'${sqlLiteral(jobIdem)}',${totalRecords},${totalAmount});`,
    "  update public.erp_import_jobs set status='validated' where tenant_id=v_tenant and id=v_job;"];
  for(const batch of plan.batches){
    lines.push(`  v_batch := public.erp_open_import_batch(v_tenant,v_job,'${batch.domain.replace(/-/g,'_')}',${batch.sequence},'${batch.batchHash}',${batch.expectedMetrics.recordCount},${batch.expectedMetrics.amountCents});`);
    for(const record of batch.records)lines.push(`  perform public.erp_record_import_item(v_tenant,v_batch,'${record.canonicalKey}','${record.sourceKeyHash}','${canonicalHash(record.payload)}',${record.payload.amountCents??0});`);
    lines.push("  update public.erp_import_batches set status='validated' where tenant_id=v_tenant and id=v_batch;");
    lines.push(`  perform public.erp_finalize_import_batch(v_tenant,v_batch,'${sha256(`${batch.batchHash}|m14-evidence`)}');`);
  }
  lines.push("  update public.erp_import_jobs set status='completed',started_at=coalesce(started_at,now()),finished_at=now() where tenant_id=v_tenant and id=v_job;");
  lines.push('end','$m14_load$;');
  const jobFilter=`j.tenant_id='${tenantId}' and j.idempotency_key='${sqlLiteral(jobIdem)}'`;
  lines.push(`select 'M14_LOAD_SUMMARY' as marcador,(select status from public.erp_import_manifests where tenant_id='${tenantId}' and idempotency_key='${sqlLiteral(idem)}') as manifesto,(select status from public.erp_import_jobs j where ${jobFilter}) as job,(select count(*) from public.erp_import_batches b join public.erp_import_jobs j on j.id=b.job_id where ${jobFilter}) as lotes,(select count(*) from public.erp_import_batches b join public.erp_import_jobs j on j.id=b.job_id where ${jobFilter} and b.status='reconciled') as reconciliados,(select count(*) from public.erp_import_batches b join public.erp_import_jobs j on j.id=b.job_id where ${jobFilter} and b.status='blocked') as bloqueados,(select count(*) from public.erp_import_items i join public.erp_import_batches b on b.id=i.batch_id join public.erp_import_jobs j on j.id=b.job_id where ${jobFilter}) as itens,(select coalesce(sum(i.source_amount_cents),0) from public.erp_import_items i join public.erp_import_batches b on b.id=i.batch_id join public.erp_import_jobs j on j.id=b.job_id where ${jobFilter}) as valor_cents,(select count(*) from public.erp_import_reconciliations r join public.erp_import_jobs j on j.id=r.job_id where ${jobFilter} and r.balanced) as balanceamentos;`);
  lines.push('commit;');
  return lines.join('\n')+'\n';
}

function parseSummary(stdout){
  const marker=stdout.match(/"marcador"\s*:\s*"M14_LOAD_SUMMARY"/);
  if(!marker)return null;
  const field=name=>{const found=stdout.match(new RegExp(`"${name}"\\s*:\\s*"?([0-9a-z_]+)"?`));return found?found[1]:null};
  return Object.fromEntries(['manifesto','job','lotes','reconciliados','bloqueados','itens','valor_cents','balanceamentos'].map(name=>[name,field(name)]));
}

function loadTenant(tenant){
  const started=Date.now();
  if(!tenant.slug||!tenant.tenantId||!tenant.expectedCnpj||!tenant.root)die(`config incompleto para ${tenant.slug??tenant.root}`);
  const root=path.resolve(tenant.root);
  const files=walk(root).sort((a,b)=>a.localeCompare(b));
  if(files.length===0)die(`${tenant.slug}: nenhum XML em ${root}`);
  const docs=[],indexLines=[];let maxMtime=0;
  const kinds={authorized:0,consultation:0,draft:0,'sat-coupon':0,unknown:0};
  const issuerMismatch=[],badFiles=[];
  for(const file of files){
    const content=readFileSync(file,'utf8');
    maxMtime=Math.max(maxMtime,statSync(file).mtimeMs);
    const relative=path.relative(root,file).split(path.sep).join('/');
    indexLines.push(`${relative}:${sha256(content)}`);
    const kind=classifyNfeDocument(content);
    kinds[kind]++;
    const label=path.basename(file);
    if(kind==='authorized'){
      try{
        const invoice=parseNfeDocument(content);
        if(invoice.issuer.document!==tenant.expectedCnpj)issuerMismatch.push(`${label}: ${invoice.issuer.document}`);
      }catch(error){badFiles.push(`${label}: ${error.message}`)}
    }
    docs.push({content,label});
  }
  if(badFiles.length)die(`${tenant.slug}: ${badFiles.length} XML autorizado sem parse (${badFiles[0]})`);
  if(issuerMismatch.length)die(`${tenant.slug}: emitente divergente do tenant (${issuerMismatch[0]}); esp. ${tenant.expectedCnpj}`);
  if(kinds.authorized===0)die(`${tenant.slug}: nenhum XML autorizado (nfeProc)`);
  const sourceSha256=sha256(indexLines.join('\n'));
  const capturedAt=new Date(maxMtime).toISOString();
  const notesHash=sha256(`authorized=${kinds.authorized}|draft=${kinds.draft}|consultation=${kinds.consultation}|sat-coupon=${kinds['sat-coupon']}|unknown=${kinds.unknown}`);
  const keys={idempotencyKey:`m14-nfe-${tenant.slug}-${sourceSha256.slice(0,12)}`,jobKey:`m14-nfe-job-${tenant.slug}-${sourceSha256.slice(0,12)}`};
  const manifest=validateSourceManifest({contractVersion:'1.1',manifestId:uuidFromSha256(sha256(`m14-manifest|${tenant.tenantId}|${sourceSha256}`)),tenantId:tenant.tenantId,extractionId:uuidFromSha256(sha256(`m14-extract|${tenant.tenantId}|${sourceSha256}`)),sourceType:'nfe-xml',sourceSha256,schemaVersion,capturedAt,immutable:true,containsRealData:true});
  const plan=planImport({tenantId:tenant.tenantId,manifest,documents:docs});
  if(plan.stats.parseErrors>0)die(`${tenant.slug}: ${plan.stats.parseErrors} XML com erro de parse no plano`);
  const stamp=new Date().toISOString().replace(/[:.]/g,'-');
  const sqlFile=path.join(workDir,`load-${tenant.slug}-${stamp}.sql`);
  writeFileSync(sqlFile,buildLoadSql(tenant,manifest,plan,notesHash,keys),'utf8');
  let summary=null;
  if(!dryRun){
    if(sqlFile.includes(' '))die('caminho do SQL contem espaco');
    const run=spawnSync('supabase',['db','query','--linked','-f',sqlFile],{cwd:repoRoot,encoding:'utf8',shell:process.platform==='win32',timeout:600000,maxBuffer:16*1024*1024});
    const stdout=`${run.stdout??''}\n${run.stderr??''}`;
    if(run.status!==0)die(`${tenant.slug}: supabase db query falhou (status ${run.status})\n${stdout.slice(-3000)}`);
    summary=parseSummary(stdout);
    if(!summary)die(`${tenant.slug}: resumo M14_LOAD_SUMMARY ausente na saida`);
    if(summary.manifesto!=='validated'||summary.job!=='completed'||summary.reconciliados!==summary.lotes||Number(summary.bloqueados)!==0||summary.balanceamentos!==summary.lotes)
      die(`${tenant.slug}: carga nao reconciliou ${JSON.stringify(summary)}`);
  }
  const report={tenant:tenant.slug,files:files.length,kinds,sourceSha256,capturedAt,manifestHash:manifest.manifestHash,sqlFile,stats:plan.stats,batches:plan.batches.map(batch=>({domain:batch.domain,sequence:batch.sequence,records:batch.records.length,amountCents:batch.expectedMetrics.amountCents,batchHash:batch.batchHash})),ledger:summary,durationMs:Date.now()-started};
  const reportFile=path.join(workDir,`report-${tenant.slug}-${stamp}.json`);
  writeFileSync(reportFile,JSON.stringify(report,null,2),'utf8');
  return{report,reportFile};
}

const results=[];
for(const tenant of config.tenants){
  console.log(`[INFO] ${tenant.slug}: processando...`);
  const{report,reportFile}=loadTenant(tenant);
  results.push({tenant:tenant.slug,reportFile,...report});
  console.log(`[OK] ${tenant.slug}: ${report.kinds.authorized} NFes, ${report.stats.records} registros, ${(report.stats.amountCents/100).toFixed(2)} BRL${dryRun?' (dry-run)':''}`);
}
const summaryFile=path.join(workDir,`load-summary-${new Date().toISOString().replace(/[:.]/g,'-')}.json`);
writeFileSync(summaryFile,JSON.stringify(results,null,2),'utf8');
console.log(`[OK] resumo geral: ${summaryFile}`);
