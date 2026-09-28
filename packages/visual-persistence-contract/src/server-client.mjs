import{createHash,randomUUID}from'node:crypto';import{COMMAND_BOUNDARIES,READ_MODELS,toPublicError,validateBrowserPayload}from'./index.mjs';
const requestPattern=/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/;
const canonical=value=>{if(Array.isArray(value))return value.map(canonical);if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])]));return value;};
const hashPayload=payload=>createHash('sha256').update(JSON.stringify(canonical(payload)),'utf8').digest('hex');
const fail=code=>{const error=new Error(code);error.code=code;throw error;};
export function createVisualPersistenceClient({transport,resolveTenant,createRequestId=()=>randomUUID()}){
 if(!transport?.rpc||!transport?.read||typeof resolveTenant!=='function')throw new Error('INVALID_SERVER_DEPENDENCY');
 return Object.freeze({
  async execute(command,payload,{requestId=createRequestId()}={}){
   const boundary=COMMAND_BOUNDARIES[command];if(!boundary)fail('INVALID_INPUT');validateBrowserPayload(payload);if(!requestPattern.test(requestId))fail('INVALID_INPUT');
   const tenantId=await resolveTenant();if(!tenantId)fail('TENANT_UNRESOLVED');
   try{const result=await transport.rpc(boundary.rpc,{p_tenant_id:tenantId,p_request_id:requestId,p_payload_hash:hashPayload(payload),p_payload:payload});const refreshed={};for(const model of boundary.refresh)refreshed[model]=await transport.read(READ_MODELS[model],tenantId);return Object.freeze({ok:true,command,requestId,result,refreshed:Object.freeze(refreshed),revalidated:true});}
   catch(error){const code=typeof error?.code==='string'?error.code:'INTERNAL_FAILURE';return Object.freeze({ok:false,command,requestId,error:toPublicError(code,error?.message??''),revalidated:false});}
  },
  async read(model){const contract=READ_MODELS[model];if(!contract)fail('INVALID_INPUT');const tenantId=await resolveTenant();if(!tenantId)fail('TENANT_UNRESOLVED');try{return Object.freeze({ok:true,model,data:await transport.read(contract,tenantId)});}catch(error){return Object.freeze({ok:false,model,error:toPublicError(error?.code??'INTERNAL_FAILURE',error?.message??'')});}}
 });
}
export{canonical,hashPayload};
