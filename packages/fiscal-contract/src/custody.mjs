const HASH=/^[a-f0-9]{64}$/;
const PILOT_ID=/^pilot-[a-z0-9-]{3,64}$/;
const SUBDOMAIN=/^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.connectioncyber\.com\.br$/;
export class CustodyPolicyError extends Error{constructor(code){super(code);this.name='CustodyPolicyError';this.code=code}}
const fail=code=>{throw new CustodyPolicyError(code)};
const forbidden=value=>JSON.stringify(value).match(/-----BEGIN|\.pfx|\.p12|password|senha|csc|\b\d{14}\b/i);

export function validatePilotDescriptor(value){
  if(!value||forbidden(value))fail('PILOT_SECRET_OR_IDENTITY_FORBIDDEN');
  if(!PILOT_ID.test(value.pilotId)||!SUBDOMAIN.test(value.subdomain))fail('INVALID_PILOT_DESCRIPTOR');
  if(value.environment!=='homologation'||value.transmissionEnabled!==false||value.productionEnabled!==false)fail('UNSAFE_PILOT_SCOPE');
  return Object.freeze({...value,validated:true});
}

export function defineA1CustodyPolicy(value){
  if(!value||forbidden(value))fail('SECRET_MATERIAL_FORBIDDEN');
  if(value.storage!=='external-vault'||value.privateKeyExportable!==false||value.gitStorage!==false||value.databaseStorage!==false)fail('INVALID_CUSTODY_STORAGE');
  if(value.importAuthorized!==false||value.signingAuthorized!==false||value.transmissionAuthorized!==false)fail('CURRENT_GATE_EXCEEDED');
  if(!Array.isArray(value.requiredApprovals)||!value.requiredApprovals.includes('certificate-import')||!value.requiredApprovals.includes('fiscal-transmission'))fail('MISSING_SEPARATE_GATES');
  return Object.freeze({...value,validated:true});
}

export function validateCertificateInventoryMetadata(value){
  if(!value||forbidden(value))fail('CERTIFICATE_MATERIAL_FORBIDDEN');
  if(!HASH.test(value.subjectHash)||!HASH.test(value.thumbprint)||typeof value.expiresAt!=='string')fail('INVALID_CERTIFICATE_METADATA');
  if(Date.parse(value.expiresAt)<=Date.now())fail('CERTIFICATE_EXPIRED');
  return Object.freeze({...value,materialPresent:false,validated:true});
}

export function maniaDeModaPilotDescriptor(){return{pilotId:'pilot-maniademoda',subdomain:'maniademoda.connectioncyber.com.br',segment:'seasonal-apparel-footwear',environment:'homologation',transmissionEnabled:false,productionEnabled:false}}
