import { createHash } from 'node:crypto';

export class FiscalContractError extends Error { constructor(code){super(code);this.name='FiscalContractError';this.code=code} }
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH=/^[a-f0-9]{64}$/;
const SECRET=/(password|senha|secret|token|credential|private.?key|service.?role|certificate|certificado|pfx|p12|csc|id.?token)/i;
const STATES={draft:['validated'],validated:['queued'],queued:['signing','contingency_pending'],signing:['signed','rejected'],signed:['transmitting','contingency_pending'],transmitting:['authorized','rejected','denied','contingency_pending'],contingency_pending:['transmitting'],authorized:['cancelled'],rejected:[],denied:[],cancelled:[]};

function fail(code){throw new FiscalContractError(code)}
function isObject(v){return v!==null&&typeof v==='object'&&!Array.isArray(v)}
function scanSecrets(value,path='$'){
  if(Array.isArray(value)){value.forEach((v,i)=>scanSecrets(v,`${path}[${i}]`));return}
  if(!isObject(value))return;
  for(const [key,val] of Object.entries(value)){if(SECRET.test(key))fail(`SECRET_FIELD_FORBIDDEN:${path}.${key}`);scanSecrets(val,`${path}.${key}`)}
}
export function canonicalize(value){if(Array.isArray(value))return`[${value.map(canonicalize).join(',')}]`;if(isObject(value))return`{${Object.keys(value).sort().map(k=>`${JSON.stringify(k)}:${canonicalize(value[k])}`).join(',')}}`;return JSON.stringify(value)}
export function payloadHash(value){return createHash('sha256').update(canonicalize(value)).digest('hex')}
export function fiscalIdempotencyKey({tenantId,environment,model,series,number,operation='issue'}){
  if(!UUID.test(tenantId)||!['homologation','production'].includes(environment)||!['55','65'].includes(model)||!Number.isInteger(series)||series<0||!Number.isInteger(number)||number<1)fail('INVALID_IDEMPOTENCY_INPUT');
  return `${tenantId}:${environment}:${model}:${series}:${number}:${operation}`;
}
export function validateIssueRequest(value,{allowProduction=false}={}){
  if(!isObject(value)||value.contractVersion!=='1.0')fail('UNSUPPORTED_VERSION');
  if(!UUID.test(value.requestId)||!UUID.test(value.tenantId)||!UUID.test(value.establishmentId))fail('INVALID_IDENTITY');
  if(!['homologation','production'].includes(value.environment)||!['55','65'].includes(value.model))fail('INVALID_FISCAL_SCOPE');
  if(value.environment==='production'&&!allowProduction)fail('PRODUCTION_KILL_SWITCH');
  if(typeof value.idempotencyKey!=='string'||value.idempotencyKey.length<16||value.idempotencyKey.length>200)fail('INVALID_IDEMPOTENCY_KEY');
  if(typeof value.saleRef!=='string'||!value.saleRef||typeof value.schemaVersion!=='string'||!value.schemaVersion)fail('INVALID_REFERENCE');
  if(!Number.isFinite(Date.parse(value.issuedAt)))fail('INVALID_TIMESTAMP');
  if(!isObject(value.taxSnapshot)||!isObject(value.totals)||!Array.isArray(value.items)||value.items.length<1||value.items.length>990)fail('INVALID_SNAPSHOT');
  if(value.model==='55'&&value.contingency?.mode==='offline')fail('OFFLINE_CONTINGENCY_NFCE_ONLY');
  scanSecrets(value);return true;
}
export function validateProviderEvent(value,{expectedTenantId,expectedEnvironment}={}){
  if(!isObject(value)||value.contractVersion!=='1.0')fail('UNSUPPORTED_VERSION');
  if(!value.eventId||!value.providerDocumentId||!UUID.test(value.tenantId))fail('INVALID_EVENT_IDENTITY');
  if(expectedTenantId&&value.tenantId!==expectedTenantId)fail('TENANT_MISMATCH');
  if(expectedEnvironment&&value.environment!==expectedEnvironment)fail('ENVIRONMENT_MISMATCH');
  if(!['55','65'].includes(value.model)||!['homologation','production'].includes(value.environment)||!Object.hasOwn(STATES,value.status))fail('INVALID_EVENT_SCOPE');
  if(!Number.isFinite(Date.parse(value.occurredAt))||!Number.isFinite(Date.parse(value.receivedAt))||!HASH.test(value.payloadHash))fail('INVALID_EVENT_EVIDENCE');
  scanSecrets(value);return true;
}
export function assertTransition(from,to){if(!STATES[from]||!STATES[from].includes(to))fail('INVALID_STATE_TRANSITION');return true}
export function assertWebhookAuthenticity({rawBody,signature,verify}){if(typeof rawBody!=='string'||!signature||typeof verify!=='function'||verify(rawBody,signature)!==true)fail('INVALID_WEBHOOK_SIGNATURE');return true}
export function reconciliationDecision({localStatus,providerStatus}){
  if(localStatus==='transmitting'&&providerStatus==='unknown')return'query_provider';
  if(providerStatus==='authorized'&&localStatus!=='authorized')return'import_authorization';
  if(localStatus===providerStatus)return'no_op';
  return'manual_review';
}

export class MemoryFiscalSimulator{
  constructor(){this.documents=new Map();this.webhooks=new Set()}
  issue(request,{response='authorized'}={}){
    validateIssueRequest(request);
    if(this.documents.has(request.idempotencyKey))return this.documents.get(request.idempotencyKey);
    const result={id:request.requestId,status:response==='timeout'?'transmitting':response,attempts:1};
    this.documents.set(request.idempotencyKey,result);return result;
  }
  retry(request){const current=this.documents.get(request.idempotencyKey);if(!current)return this.issue(request);current.attempts+=1;return current}
  reconcile(idempotencyKey,providerStatus){const current=this.documents.get(idempotencyKey);if(!current)fail('DOCUMENT_NOT_FOUND');const action=reconciliationDecision({localStatus:current.status,providerStatus});if(action==='import_authorization')current.status='authorized';return action}
  receiveWebhook(event,{signatureValid=true}={}){validateProviderEvent(event);assertWebhookAuthenticity({rawBody:canonicalize(event),signature:signatureValid?'valid':'invalid',verify:(_b,s)=>s==='valid'});const key=`${event.provider}:${event.environment}:${event.eventId}`;if(this.webhooks.has(key))return'duplicate';this.webhooks.add(key);return'accepted'}
}
