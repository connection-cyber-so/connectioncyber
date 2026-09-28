import test from 'node:test'
import assert from 'node:assert/strict'
import { buildSyntheticProfileMatrix, capabilityStatus, resolveOperationalCapabilities } from '../src/engine.mjs'
const manifest=(legalProfile='LTDA',exceptions=[])=>({version:1,tenantId:`SYNTHETIC-TENANT-ENGINE-${legalProfile}`,legalProfile,exceptions})
const readiness={consentReady:true,deviceReady:true,fiscalValidated:true,sourceValidated:true}
const exception=(id,capability,effect='deny')=>({id:`SYNTHETIC-EX-${id}`,capability,effect,reason:'SYNTHETIC-ENGINE-TEST',approvedBy:'SYNTHETIC-APPROVER-SECURITY',expiresAt:'2027-01-01T00:00:00.000Z'})
test('matriz cobre MEI ME LTDA',()=>assert.deepEqual(buildSyntheticProfileMatrix().rows.map(row=>row.legalProfile),['MEI','ME','LTDA']))
test('matriz usa todas as capacidades',()=>assert.equal(buildSyntheticProfileMatrix().columns.length,12))
test('MEI mantém estoque desabilitado',()=>assert.equal(buildSyntheticProfileMatrix().rows[0].states.inventory,'disabled'))
test('ME mantém estoque habilitado',()=>assert.equal(buildSyntheticProfileMatrix().rows[1].states.inventory,'enabled'))
test('LTDA bloqueia fiscal sem prontidão',()=>assert.equal(buildSyntheticProfileMatrix().rows[2].states.fiscal,'blocked'))
test('fiscal é liberado somente com prontidão',()=>assert.equal(capabilityStatus(resolveOperationalCapabilities(manifest(),{readiness}),'fiscal').status,'enabled'))
test('suporte remoto exige consentimento',()=>assert.equal(capabilityStatus(resolveOperationalCapabilities(manifest(),{readiness:{...readiness,consentReady:false}}),'remote_support').status,'blocked'))
test('agente exige dispositivo pronto',()=>assert.equal(capabilityStatus(resolveOperationalCapabilities(manifest(),{readiness:{...readiness,deviceReady:false}}),'device_agent').status,'blocked'))
test('importação exige fonte validada',()=>assert.equal(capabilityStatus(resolveOperationalCapabilities(manifest(),{readiness:{...readiness,sourceValidated:false}}),'legacy_import').status,'blocked'))
test('dependência negada bloqueia venda',()=>{const result=resolveOperationalCapabilities(manifest('ME',[exception('CATALOG','catalog')]),{readiness});assert.equal(capabilityStatus(result,'sales').status,'blocked')})
test('venda bloqueada propaga para caixa',()=>{const result=resolveOperationalCapabilities(manifest('ME',[exception('SALES','sales')]),{readiness});assert.equal(capabilityStatus(result,'cash').status,'blocked')})
test('caixa bloqueado propaga para financeiro',()=>{const result=resolveOperationalCapabilities(manifest('ME',[exception('CASH','cash')]),{readiness});assert.equal(capabilityStatus(result,'finance').status,'blocked')})
test('capacidade desconhecida falha fechada',()=>assert.equal(capabilityStatus(resolveOperationalCapabilities(manifest(),{readiness}),'root').status,'blocked'))
test('chave de prontidão desconhecida é recusada',()=>assert.throws(()=>resolveOperationalCapabilities(manifest(),{readiness:{rootReady:true}}),/UNKNOWN_READINESS_KEY/))
test('valor de prontidão não booleano é recusado',()=>assert.throws(()=>resolveOperationalCapabilities(manifest(),{readiness:{fiscalValidated:'yes'}}),/INVALID_READINESS_VALUE/))
test('resolução operacional não acessa remoto',()=>{const result=resolveOperationalCapabilities(manifest(),{readiness});assert.equal(result.remoteAccessed,false);assert.equal(result.productionAccessed,false)})
test('marcador determinístico é emitido',()=>assert.equal(buildSyntheticProfileMatrix().result,'M16_G2_FAIL_CLOSED_ENGINE_OK'))
