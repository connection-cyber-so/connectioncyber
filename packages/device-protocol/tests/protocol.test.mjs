import assert from 'node:assert/strict';
import { generateKeyPairSync, randomBytes, randomUUID } from 'node:crypto';
import test from 'node:test';
import { MemoryReplayStore, ProtocolValidationError, canonicalize, hashOfflineOperation, signEnvelope, validateEnvelope, validateOfflineChain, verifyEnvelope } from '../src/index.mjs';

const { privateKey, publicKey } = generateKeyPairSync('ed25519');
const now = new Date('2026-08-28T12:00:00.000Z');
function envelope(overrides={}){return{protocolVersion:'1.0',messageId:randomUUID(),tenantId:'12000000-0000-4000-8000-000000000001',establishmentId:'13000000-0000-4000-8000-000000000001',agentId:'14000000-0000-4000-8000-000000000001',type:'print.execute',issuedAt:now.toISOString(),expiresAt:new Date(now.getTime()+120000).toISOString(),nonce:randomBytes(24).toString('base64url'),idempotencyKey:`print:${randomUUID()}`,keyId:'agent-key-v1',payload:{printerLogicalId:'receipt-01',documentHash:'a'.repeat(64),copies:1},...overrides}}

test('canonicalização independe da ordem das chaves',()=>assert.equal(canonicalize({b:2,a:{d:4,c:3}}),canonicalize({a:{c:3,d:4},b:2})));
test('envelope válido é assinado e verificado com Ed25519',()=>{const signed=signEnvelope(envelope(),privateKey,{now});assert.equal(verifyEnvelope(signed,publicKey,{now}),true)});
test('alteração após assinatura é recusada',()=>{const signed=signEnvelope(envelope(),privateKey,{now});assert.throws(()=>verifyEnvelope({...signed,payload:{...signed.payload,copies:2}},publicKey,{now}),/INVALID_SIGNATURE/)});
test('tenant divergente é recusado',()=>{const signed=signEnvelope(envelope(),privateKey,{now});assert.throws(()=>verifyEnvelope(signed,publicKey,{now,expectedTenantId:'22000000-0000-4000-8000-000000000001'}),/TENANT_MISMATCH/)});
test('agente divergente é recusado',()=>{const signed=signEnvelope(envelope(),privateKey,{now});assert.throws(()=>verifyEnvelope(signed,publicKey,{now,expectedAgentId:'24000000-0000-4000-8000-000000000001'}),/AGENT_MISMATCH/)});
test('replay do mesmo nonce é recusado',()=>{const store=new MemoryReplayStore(),signed=signEnvelope(envelope(),privateKey,{now});assert.equal(verifyEnvelope(signed,publicKey,{now,replayStore:store}),true);assert.throws(()=>verifyEnvelope(signed,publicKey,{now,replayStore:store}),/REPLAY_DETECTED/)});
test('mensagem expirada é recusada',()=>{const value=envelope({issuedAt:'2026-08-28T11:50:00.000Z',expiresAt:'2026-08-28T11:51:00.000Z'});assert.throws(()=>validateEnvelope(value,{now}),/EXPIRED_MESSAGE/)});
test('TTL superior a cinco minutos é recusado',()=>assert.throws(()=>validateEnvelope(envelope({expiresAt:'2026-08-28T12:06:00.000Z'}),{now}),/INVALID_TTL/));
test('campos de segredo são recusados em profundidade',()=>assert.throws(()=>validateEnvelope(envelope({payload:{device:{serviceRole:'proibido'}}}),{now}),/SECRET_FIELD_FORBIDDEN/));
test('versão desconhecida é recusada',()=>assert.throws(()=>validateEnvelope(envelope({protocolVersion:'2.0'}),{now}),/UNSUPPORTED_VERSION/));
test('cadeia offline íntegra é aceita',()=>{const first={operationId:randomUUID(),previousHash:null,tenantId:'12000000-0000-4000-8000-000000000001',sequence:1,payload:{saleTotal:10}};first.operationHash=hashOfflineOperation(first);const second={operationId:randomUUID(),previousHash:first.operationHash,tenantId:first.tenantId,sequence:2,payload:{saleTotal:20}};second.operationHash=hashOfflineOperation(second);assert.equal(validateOfflineChain([first,second]),true)});
test('adulteração ou quebra da cadeia offline é recusada',()=>{const operation={operationId:randomUUID(),previousHash:null,tenantId:'12000000-0000-4000-8000-000000000001',sequence:1,payload:{saleTotal:10}};operation.operationHash=hashOfflineOperation(operation);operation.payload.saleTotal=999;assert.throws(()=>validateOfflineChain([operation]),ProtocolValidationError)});
