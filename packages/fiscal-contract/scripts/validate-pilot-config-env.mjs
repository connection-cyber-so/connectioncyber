import { validatePilotFiscalConfig } from '../src/pilot-config.mjs';
const get=name=>process.env[`M13_G18_${name}`];
const input={credentialedHomologation:get('CREDENTIALED')==='true',certificateMatchesIssuer:get('A1_MATCH')==='true',state:get('STATE'),stateCode:get('STATE_CODE'),municipalityCode:get('MUNICIPALITY_CODE'),stateRegistration:get('STATE_REGISTRATION'),crt:get('CRT'),series:Number(get('SERIES')),number:Number(get('NUMBER')),ncm:get('NCM'),cfop:get('CFOP'),csosn:get('CSOSN'),operationApproved:get('OPERATION_APPROVED')==='true'};
const result=validatePilotFiscalConfig(input);
console.log(JSON.stringify({result:result.ready?'M13_G18_PROTECTED_CONFIG_OK':'M13_G18_PROTECTED_CONFIG_BLOCKED',ready:result.ready,blockers:result.blockers,valuesPrinted:false,persisted:false,xmlGenerated:false,signed:false,transmitted:false,productionAccessed:false}));
process.exitCode=result.ready?0:2;
