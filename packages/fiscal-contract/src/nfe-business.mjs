import{createHash}from'node:crypto';
export class NFeBusinessError extends Error{constructor(code){super(code);this.name='NFeBusinessError';this.code=code}}
const fail=code=>{throw new NFeBusinessError(code)};
const digits=(value,length)=>typeof value==='string'&&new RegExp(`^\\d{${length}}$`).test(value);
const integer=value=>Number.isSafeInteger(value)&&value>=0;

export function calculateAccessKeyDigit(base43){
  if(!digits(base43,43))fail('REJECTION_236_INVALID_ACCESS_KEY');
  let weight=2,sum=0;for(let index=42;index>=0;index--){sum+=Number(base43[index])*weight;weight=weight===9?2:weight+1}
  const candidate=11-(sum%11);return candidate===10||candidate===11?0:candidate;
}

export function composeSyntheticAccessKey({stateCode,yearMonth,syntheticTaxId='00000000000000',model='55',series,number,emissionType='1',numericCode}){
  if(!digits(stateCode,2)||!digits(yearMonth,4)||syntheticTaxId!=='00000000000000'||model!=='55'||!digits(series,3)||!digits(number,9)||emissionType!=='1'||!digits(numericCode,8))fail('REJECTION_SYNTHETIC_SCOPE_INVALID');
  const base=`${stateCode}${yearMonth}${syntheticTaxId}${model}${series}${number}${emissionType}${numericCode}`;
  return`${base}${calculateAccessKeyDigit(base)}`;
}

export function validateAccessKey(key){if(!digits(key,44)||calculateAccessKeyDigit(key.slice(0,43))!==Number(key[43]))fail('REJECTION_236_INVALID_ACCESS_KEY');return true}

export function reconcileNFeTotals({items,totals,payments}){
  if(!Array.isArray(items)||items.length<1||!items.every(item=>integer(item.productCents)&&integer(item.discountCents??0)))fail('REJECTION_508_INVALID_ITEM_TOTAL');
  const productCents=items.reduce((sum,item)=>sum+item.productCents,0),discountCents=items.reduce((sum,item)=>sum+(item.discountCents??0),0);
  for(const field of['freightCents','insuranceCents','otherCents','ipiCents','stCents','desonerationCents','invoiceCents'])if(!integer(totals?.[field]??0))fail('REJECTION_564_INVALID_TOTAL');
  const expected=productCents+(totals.freightCents??0)+(totals.insuranceCents??0)+(totals.otherCents??0)+(totals.ipiCents??0)+(totals.stCents??0)-discountCents-(totals.desonerationCents??0);
  if(expected!==totals.invoiceCents)fail('REJECTION_564_INVALID_TOTAL');
  if(!Array.isArray(payments)||!payments.every(payment=>integer(payment.amountCents)))fail('REJECTION_865_INVALID_PAYMENT_TOTAL');
  const noPayment=payments.length===1&&payments[0].method==='90'&&payments[0].amountCents===0;
  if(!noPayment&&payments.reduce((sum,payment)=>sum+payment.amountCents,0)!==totals.invoiceCents)fail('REJECTION_865_INVALID_PAYMENT_TOTAL');
  return Object.freeze({productCents,discountCents,invoiceCents:expected,paymentMode:noPayment?'no_payment':'settled'});
}

export function deterministicBatchId({accessKey,idempotencyKey}){
  validateAccessKey(accessKey);if(typeof idempotencyKey!=='string'||idempotencyKey.length<16)fail('INVALID_IDEMPOTENCY_KEY');
  const value=BigInt(`0x${createHash('sha256').update(`${accessKey}:${idempotencyKey}`).digest('hex')}`)%999999999999999n+1n;return value.toString();
}

export function buildEnviNFe({batchId,accessKey,nfeXml}){
  if(!digits(batchId,1)&&!digits(batchId,2)&&!digits(batchId,3)&&!/^\d{1,15}$/.test(batchId))fail('REJECTION_238_INVALID_BATCH');
  if(typeof nfeXml!=='string')fail('REJECTION_UNSAFE_XML');const taxIds=[...nfeXml.matchAll(/<CNPJ>(\d{14})<\/CNPJ>/g)].map(match=>match[1]);
  validateAccessKey(accessKey);if(!nfeXml.includes('<NFe')||/<Signature\b/.test(nfeXml)||taxIds.some(value=>value!=='00000000000000'))fail('REJECTION_UNSAFE_XML');
  return`<enviNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00"><idLote>${batchId}</idLote><indSinc>0</indSinc>${nfeXml}</enviNFe>`;
}

export class LocalBatchRegistry{
  #entries=new Map();
  submit({batchId,contentHash}){if(!/^\d{1,15}$/.test(batchId)||!/^\w{16,128}$/.test(contentHash))fail('INVALID_BATCH_REGISTRATION');const existing=this.#entries.get(batchId);if(existing&&existing!==contentHash)fail('REJECTION_539_DUPLICATE_BATCH_CONFLICT');if(existing)return Object.freeze({status:'duplicate',attempts:1});this.#entries.set(batchId,contentHash);return Object.freeze({status:'accepted_local',attempts:1})}
  size(){return this.#entries.size}
}
