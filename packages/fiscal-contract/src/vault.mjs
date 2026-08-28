const REFERENCE=/^(vault|hsm|psc|seal):\/\/[A-Za-z0-9._:/-]{8,240}$/;
const HASH=/^[a-f0-9]{64}$/;
export class FiscalVaultError extends Error{constructor(code){super(code);this.name='FiscalVaultError';this.code=code}}
const fail=code=>{throw new FiscalVaultError(code)};
export class ReferenceOnlyVault{
  #refs=new Map();
  register({tenantId,establishmentId,reference,subjectHash,thumbprint,mode}){
    if(typeof reference!=='string'||/-----BEGIN|\.pfx$|\.p12$/i.test(reference))fail('SECRET_MATERIAL_FORBIDDEN');
    if(!REFERENCE.test(reference)||!HASH.test(subjectHash)||!HASH.test(thumbprint)||!['vault','hsm','psc','seal'].includes(mode))fail('INVALID_VAULT_REFERENCE');
    const key=`${tenantId}:${establishmentId}`,value=Object.freeze({tenantId,establishmentId,reference,subjectHash,thumbprint,mode});this.#refs.set(key,value);return value
  }
  getReference(tenantId,establishmentId){return this.#refs.get(`${tenantId}:${establishmentId}`)??null}
  exportMaterial(){fail('SECRET_EXPORT_FORBIDDEN')}
}
