import test from'node:test';import assert from'node:assert/strict';import{evaluatePilotPreflight,pilotPreflightRequiredFields}from'../src/pilot-preflight.mjs';
const complete=()=>({credentialedHomologation:true,certificateMatchesIssuer:true,state:'SP',stateCode:'35',municipalityCode:'3550308',stateRegistration:'synthetic',crt:'1',series:900,number:1,ncm:'00000000',cfop:'5102',csosn:'102',operationApproved:true});
test('preflight vazio bloqueia todos os requisitos',()=>assert.equal(evaluatePilotPreflight().blockers.length,pilotPreflightRequiredFields.length));
test('preflight completo fica pronto',()=>assert.equal(evaluatePilotPreflight(complete()).ready,true));
for(const field of pilotPreflightRequiredFields)test(`campo obrigatório bloqueia: ${field}`,()=>{const value=complete();delete value[field];assert.equal(evaluatePilotPreflight(value).blockers.includes(field),true)});
test('segredo é proibido',()=>assert.equal(evaluatePilotPreflight({...complete(),password:'x'}).ready,false));
test('PFX é proibido',()=>assert.equal(evaluatePilotPreflight({...complete(),pfx:'x'}).ready,false));
test('CSC é proibido',()=>assert.equal(evaluatePilotPreflight({...complete(),csc:'x'}).ready,false));
test('preflight nunca gera ou transmite XML',()=>{const result=evaluatePilotPreflight(complete());assert.equal(result.xmlGenerated,false);assert.equal(result.signed,false);assert.equal(result.persisted,false);assert.equal(result.transmitted,false);assert.equal(result.productionAccessed,false)});
