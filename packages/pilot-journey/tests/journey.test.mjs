import test from 'node:test'
import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { SyntheticPilotLab, executeSyntheticJourney } from '../src/index.mjs'
const setup=(role='owner',mfa=true)=>{const lab=new SyntheticPilotLab(),a=lab.createTenant({legalProfile:'ME',name:'SYNTHETIC-A'}),b=lab.createTenant({legalProfile:'LTDA',name:'SYNTHETIC-B'}),session=lab.authenticate({userId:'SYNTHETIC-USER',tenantId:a.id,role,mfa});return{lab,a,b,session}}
test('jornada completa aprovada',()=>assert.equal(executeSyntheticJourney().result,'M15_G2_SYNTHETIC_JOURNEY_OK'))
test('perfis MEI ME LTDA',()=>assert.deepEqual(executeSyntheticJourney().profiles,['MEI','ME','LTDA']))
test('seis módulos operacionais',()=>assert.equal(executeSyntheticJourney().modules.length,6))
test('cross-tenant negado',()=>assert.equal(executeSyntheticJourney().crossTenantDenied,true))
test('fiscal fail-closed',()=>assert.equal(executeSyntheticJourney().fiscalFailClosed,true))
test('owner exige MFA',()=>{const lab=new SyntheticPilotLab(),t=lab.createTenant({legalProfile:'ME',name:'SYNTHETIC-A'});assert.throws(()=>lab.authenticate({userId:'SYNTHETIC-U',tenantId:t.id,role:'owner'}),/MFA_REQUIRED/)})
test('admin exige MFA',()=>{const lab=new SyntheticPilotLab(),t=lab.createTenant({legalProfile:'ME',name:'SYNTHETIC-A'});assert.throws(()=>lab.authenticate({userId:'SYNTHETIC-U',tenantId:t.id,role:'admin'}),/MFA_REQUIRED/)})
test('papel inválido negado',()=>{const lab=new SyntheticPilotLab(),t=lab.createTenant({legalProfile:'ME',name:'SYNTHETIC-A'});assert.throws(()=>lab.authenticate({userId:'SYNTHETIC-U',tenantId:t.id,role:'root',mfa:true}),/INVALID_ROLE/)})
test('tenant inexistente negado',()=>assert.throws(()=>new SyntheticPilotLab().authenticate({userId:'SYNTHETIC-U',tenantId:randomUUID(),role:'operator'}),/TENANT_NOT_FOUND/))
test('perfil jurídico inválido negado',()=>assert.throws(()=>new SyntheticPilotLab().createTenant({legalProfile:'SA',name:'SYNTHETIC-SA'}),/INVALID_SYNTHETIC_TENANT/))
test('nome real negado',()=>assert.throws(()=>new SyntheticPilotLab().createTenant({legalProfile:'ME',name:'Empresa Real'}),/INVALID_SYNTHETIC_TENANT/))
test('viewer não escreve',()=>{const{lab,a,session}=setup('viewer',false);assert.throws(()=>lab.write(session,a.id,'sales',{sale:'SYNTHETIC-SALE'},'m15g2:sale:1'),/PERMISSION_DENIED/)})
test('finance acessa financeiro',()=>{const{lab,a,session}=setup('finance',false);assert.equal(lab.access(session,a.id,'finance').allowed,true)})
test('finance não acessa venda',()=>{const{lab,a,session}=setup('finance',false);assert.throws(()=>lab.access(session,a.id,'sales'),/PERMISSION_DENIED/)})
test('operator acessa venda',()=>{const{lab,a,session}=setup('operator',false);assert.equal(lab.access(session,a.id,'sales').allowed,true)})
test('operator não acessa financeiro',()=>{const{lab,a,session}=setup('operator',false);assert.throws(()=>lab.access(session,a.id,'finance'),/PERMISSION_DENIED/)})
test('payload não sintético negado',()=>{const{lab,a,session}=setup();assert.throws(()=>lab.write(session,a.id,'sales',{sale:'SALE'},'m15g2:sale:1'),/REAL_OR_SECRET/)})
test('segredo em payload negado',()=>{const{lab,a,session}=setup();assert.throws(()=>lab.write(session,a.id,'sales',{sale:'SYNTHETIC',password:'x'},'m15g2:sale:1'),/REAL_OR_SECRET/)})
test('replay idempotente não duplica',()=>{const{lab,a,session}=setup(),payload={sale:'SYNTHETIC-SALE'};lab.write(session,a.id,'sales',payload,'m15g2:sale:1');assert.equal(lab.write(session,a.id,'sales',payload,'m15g2:sale:1').replayed,true);assert.equal(lab.count(a.id,'sales'),1)})
test('conflito idempotente negado',()=>{const{lab,a,session}=setup();lab.write(session,a.id,'sales',{sale:'SYNTHETIC-A'},'m15g2:sale:1');assert.throws(()=>lab.write(session,a.id,'sales',{sale:'SYNTHETIC-B'},'m15g2:sale:1'),/IDEMPOTENCY_CONFLICT/)})
test('módulo desconhecido negado',()=>{const{lab,a,session}=setup();assert.throws(()=>lab.access(session,a.id,'unknown'),/UNKNOWN_MODULE/)})
test('rollback remove registros',()=>{const{lab,a,session}=setup();lab.write(session,a.id,'sales',{sale:'SYNTHETIC-A'},'m15g2:sale:1');assert.deepEqual(lab.rollback(),{removed:1,remaining:0})})
test('sem remoto e produção',()=>{const r=executeSyntheticJourney();assert.equal(r.afterRollback.remoteAccessed,false);assert.equal(r.afterRollback.productionAccessed,false)})
test('sem persistência após rollback',()=>assert.equal(executeSyntheticJourney().afterRollback.records,0))
