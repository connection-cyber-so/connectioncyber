import { payloadHash, validateIssueRequest } from './index.mjs';

const HOMOLOGATION_BASE_URL='https://homologacao.focusnfe.com.br';
const FORBIDDEN=/(password|senha|secret|private.?key|certificate|certificado|pfx|p12|csc|id.?token)/i;
export class FocusHomologationError extends Error{constructor(code){super(code);this.name='FocusHomologationError';this.code=code}}
function fail(code){throw new FocusHomologationError(code)}
function scan(value){if(Array.isArray(value)){value.forEach(scan);return}if(!value||typeof value!=='object')return;for(const[k,v]of Object.entries(value)){if(FORBIDDEN.test(k))fail('SECRET_FIELD_FORBIDDEN');scan(v)}}

export function createFocusHomologationAdapter({token,fetchImpl=globalThis.fetch,timeoutMs=8000}={}){
  if(typeof token!=='string'||token.trim().length<8)fail('FOCUS_HOMOLOGATION_TOKEN_MISSING');
  if(typeof fetchImpl!=='function'||!Number.isInteger(timeoutMs)||timeoutMs<1000||timeoutMs>30000)fail('INVALID_ADAPTER_CONFIG');
  const authorization=`Basic ${Buffer.from(`${token.trim()}:`,'utf8').toString('base64')}`;
  async function request(path,{method='GET',body,idempotencyKey}={}){
    if(!path.startsWith('/v2/')||path.includes('..')||/^https?:/i.test(path))fail('INVALID_FOCUS_PATH');
    scan(body);const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),timeoutMs);
    try{const response=await fetchImpl(`${HOMOLOGATION_BASE_URL}${path}`,{method,headers:{Accept:'application/json',Authorization:authorization,...(body?{'Content-Type':'application/json'}:{}),...(idempotencyKey?{'X-ConnectionCyber-Idempotency-Key':idempotencyKey}:{})},body:body?JSON.stringify(body):undefined,signal:controller.signal});const text=await response.text();let data=null;try{data=text?JSON.parse(text):null}catch{data={unparsed:true}}return{ok:response.ok,status:response.status,data,responseHash:payloadHash({status:response.status,body:text})}}catch(error){if(error?.name==='AbortError')fail('FOCUS_TIMEOUT');fail('FOCUS_NETWORK_ERROR')}finally{clearTimeout(timer)}}
  return{environment:'homologation',baseUrl:HOMOLOGATION_BASE_URL,request,prepareIssue(canonical){validateIssueRequest(canonical);if(canonical.environment!=='homologation')fail('PRODUCTION_FORBIDDEN');scan(canonical);return{reference:canonical.idempotencyKey,model:canonical.model,payloadHash:payloadHash(canonical)}}};
}

export function syntheticFocusProbe(){return{contractVersion:'1.0',requestId:'14000000-0000-4000-8000-000000000001',tenantId:'12000000-0000-4000-8000-000000000001',establishmentId:'13000000-0000-4000-8000-000000000001',environment:'homologation',model:'65',idempotencyKey:'synthetic-focus-homologation-001',saleRef:'synthetic-sale-001',issuedAt:'2026-08-28T12:00:00-03:00',schemaVersion:'synthetic-v1',taxSnapshot:{regime:'synthetic'},items:[{line:1,description:'PRODUTO SINTETICO',amount:'1.00'}],totals:{amount:'1.00'},contingency:null}}
