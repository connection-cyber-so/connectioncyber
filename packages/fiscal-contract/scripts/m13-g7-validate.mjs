import{createHash}from'node:crypto';import{createA1ImportPreparation,EphemeralSecret}from'../src/a1-import.mjs';
const digest=value=>createHash('sha256').update(value).digest('hex');
const material=Buffer.from([0x30,0x82,0x01,0x00,1,2,3]);
const secretBytes=Buffer.from('synthetic-only');
const workflow=createA1ImportPreparation({source:{kind:'ephemeral-local',async readOnce(){return material}},secretProvider:{kind:'hidden-prompt',async request(){return new EphemeralSecret(secretBytes)}},inspector:{kind:'metadata-only',async inspect(){return{subjectHash:digest('synthetic-subject'),thumbprint:digest('synthetic-thumbprint'),expiresAt:'2099-01-01T00:00:00Z',chainValid:true,privateKeyExtracted:false,signed:false}}},vault:{kind:'reference-only',async registerMetadata(){return{reference:'vault://pilot/metadata-only'}}}});
const result=await workflow.inspect({pilotId:'pilot-maniademoda',certificateHandle:'local-handle:synthetic-a1'});
console.log(JSON.stringify({result:'M13_G7_IMPORT_PREPARATION_OK',chainValid:result.chainValid,materialPersisted:result.materialPersisted,privateKeyExtracted:result.privateKeyExtracted,signed:result.signed,transmitted:result.transmitted,buffersCleared:material.every(x=>x===0)&&secretBytes.every(x=>x===0)}));
