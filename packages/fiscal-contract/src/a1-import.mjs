import{validateCertificateInventoryMetadata}from'./custody.mjs';
export class A1ImportError extends Error{constructor(code){super(code);this.name='A1ImportError';this.code=code}}
const fail=code=>{throw new A1ImportError(code)};

export class EphemeralSecret{
  #bytes;#consumed=false;
  constructor(bytes){if(!Buffer.isBuffer(bytes)||bytes.length<1)fail('EMPTY_SECRET');this.#bytes=bytes}
  consume(){if(this.#consumed)fail('SECRET_ALREADY_CONSUMED');this.#consumed=true;return this.#bytes}
  dispose(){this.#bytes?.fill(0)}
  toString(){return'[REDACTED]'}
  toJSON(){return'[REDACTED]'}
}

export function createA1ImportPreparation({source,secretProvider,inspector,vault}){
  if(source?.kind!=='ephemeral-local'||secretProvider?.kind!=='hidden-prompt'||inspector?.kind!=='metadata-only'||vault?.kind!=='reference-only')fail('UNSAFE_ADAPTER');
  return{async inspect({pilotId,certificateHandle}){
    if(!/^pilot-[a-z0-9-]+$/.test(pilotId)||!/^local-handle:[a-z0-9-]{8,64}$/.test(certificateHandle))fail('INVALID_IMPORT_REQUEST');
    let material,secret;
    try{
      material=await source.readOnce(certificateHandle);
      if(!Buffer.isBuffer(material)||material.length<4||material[0]!==0x30)fail('INVALID_PKCS12_CONTAINER');
      secret=await secretProvider.request();
      if(!(secret instanceof EphemeralSecret))fail('UNSAFE_SECRET_PROVIDER');
      const metadata=await inspector.inspect({material,secret:secret.consume(),validateChain:true,extractPrivateKey:false,sign:false});
      if(metadata.privateKeyExtracted||metadata.signed||metadata.chainValid!==true)fail('CERTIFICATE_VALIDATION_FAILED');
      const safe=validateCertificateInventoryMetadata(metadata);
      const stored=await vault.registerMetadata({pilotId,certificateHandle,subjectHash:safe.subjectHash,thumbprint:safe.thumbprint,expiresAt:safe.expiresAt});
      return Object.freeze({pilotId,reference:stored.reference,subjectHash:safe.subjectHash,thumbprint:safe.thumbprint,expiresAt:safe.expiresAt,chainValid:true,materialPersisted:false,privateKeyExtracted:false,signed:false,transmitted:false});
    }finally{material?.fill(0);secret?.dispose()}
  }}
}
