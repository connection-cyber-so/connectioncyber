import test from 'node:test'
import assert from 'node:assert/strict'
import { evaluateSyntheticHypercare, executeSyntheticHypercare } from '../src/index.mjs'
const healthy={name:'SYNTHETIC-HEALTHY',availabilityPct:100,errorRatePct:0,p95Ms:200,reconciliationPending:0,crossTenantEvents:0,fiscalProductionEvents:0}
test('preparação local emite marcador determinístico',()=>assert.equal(executeSyntheticHypercare().result,'M15_G11_LOCAL_PREPARATION_OK'))
test('amostra saudável permanece sem alerta',()=>assert.equal(evaluateSyntheticHypercare(healthy).status,'HEALTHY'))
test('evento cross-tenant é SEV-1',()=>assert.equal(evaluateSyntheticHypercare({...healthy,crossTenantEvents:1}).status,'SEV-1'))
test('evento fiscal de produção é SEV-1',()=>assert.equal(evaluateSyntheticHypercare({...healthy,fiscalProductionEvents:1}).status,'SEV-1'))
test('disponibilidade baixa é SEV-2',()=>assert.equal(evaluateSyntheticHypercare({...healthy,availabilityPct:99}).status,'SEV-2'))
test('erro alto é SEV-2',()=>assert.equal(evaluateSyntheticHypercare({...healthy,errorRatePct:2}).status,'SEV-2'))
test('latência alta é SEV-2',()=>assert.equal(evaluateSyntheticHypercare({...healthy,p95Ms:1300}).status,'SEV-2'))
test('reconciliação pendente é SEV-2',()=>assert.equal(evaluateSyntheticHypercare({...healthy,reconciliationPending:1}).status,'SEV-2'))
test('amostra incompleta falha fechada',()=>assert.throws(()=>evaluateSyntheticHypercare({name:'SYNTHETIC-INCOMPLETE'}),/INCOMPLETE_HYPERCARE_SAMPLE/))
test('dados não sintéticos são recusados',()=>assert.throws(()=>evaluateSyntheticHypercare({...healthy,name:'REAL'}),/REAL_OR_SECRET_DATA_FORBIDDEN/))
test('simulador nunca libera produção',()=>{const result=executeSyntheticHypercare();assert.equal(result.acceptanceBlocked,true);assert.equal(result.productionAccessed,false)})
