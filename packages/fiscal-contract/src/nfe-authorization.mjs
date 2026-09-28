export class NFeAuthorizationError extends Error{constructor(code){super(code);this.name='NFeAuthorizationError';this.code=code}}
const fail=code=>{throw new NFeAuthorizationError(code)};
const TRANSITIONS={draft:['submitted'],submitted:['received','timeout'],received:['processing'],processing:['authorized','rejected','timeout'],timeout:['querying'],querying:['processing','authorized','rejected','not_found'],not_found:['querying'],authorized:[],rejected:[]};
export function transitionAuthorization(from,to){if(!TRANSITIONS[from]?.includes(to))fail('INVALID_AUTHORIZATION_TRANSITION');return to}
export function reconcileAuthorization({localState,remoteState,localProtocol,remoteProtocol}){
  if(remoteState==='authorized'&&remoteProtocol){if(localProtocol&&localProtocol!==remoteProtocol)return'manual_protocol_conflict';return localState==='authorized'?'no_op':'import_protocol'}
  if(localState==='timeout'||localState==='querying')return remoteState==='not_found'?'wait_and_query':'continue_query';
  if(remoteState==='rejected')return localState==='rejected'?'no_op':'import_rejection';
  return localState===remoteState?'no_op':'manual_review';
}
export class LocalNFeAuthorizationSimulator{
  #documents=new Map();#receipts=new Map();#counter=0;
  submit({accessKey,batchId,contentHash,scenario='authorized'}){
    if(!/^\d{44}$/.test(accessKey)||!/^\d{1,15}$/.test(batchId)||!/^[a-f0-9]{64}$/.test(contentHash)||!['authorized','rejected','timeout','duplicate_authorized'].includes(scenario))fail('INVALID_SIMULATION_INPUT');
    const existing=this.#documents.get(accessKey);if(existing){if(existing.contentHash!==contentHash)fail('REJECTION_539_DUPLICATE_KEY_CONFLICT');return Object.freeze({status:'duplicate',accessKey,protocol:existing.protocol??null,action:existing.protocol?'reconcile_protocol':'query_status'})}
    const receipt=`SYNTH-${String(++this.#counter).padStart(6,'0')}`,document={accessKey,batchId,contentHash,state:'received',receipt,protocol:null};this.#documents.set(accessKey,document);this.#receipts.set(receipt,accessKey);
    if(scenario==='timeout'){document.state='timeout';return Object.freeze({status:'timeout',receipt,action:'query_status'})}
    document.state='processing';if(scenario==='rejected'){document.state='rejected';return Object.freeze({status:'rejected',receipt,code:'SYNTHETIC_REJECTION'})}
    document.state='authorized';document.protocol=`SYNTH-PROTOCOL-${accessKey.slice(-8)}`;return Object.freeze({status:scenario==='duplicate_authorized'?'duplicate_authorized':'authorized',receipt,protocol:document.protocol})
  }
  query(receipt,{resolveAs='authorized'}={}){const key=this.#receipts.get(receipt);if(!key)return Object.freeze({status:'not_found'});const document=this.#documents.get(key);if(document.state==='authorized'||document.state==='rejected')return Object.freeze({status:document.state,protocol:document.protocol});if(resolveAs==='pending')return Object.freeze({status:'processing',action:'query_later'});if(resolveAs==='rejected'){document.state='rejected';return Object.freeze({status:'rejected',code:'SYNTHETIC_REJECTION'})}document.state='authorized';document.protocol=`SYNTH-PROTOCOL-${key.slice(-8)}`;return Object.freeze({status:'authorized',protocol:document.protocol})}
  size(){return this.#documents.size}
}
