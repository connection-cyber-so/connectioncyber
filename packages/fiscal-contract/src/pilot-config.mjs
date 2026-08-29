import { evaluatePilotPreflight } from './pilot-preflight.mjs';

const UF_CODES=Object.freeze({RO:'11',AC:'12',AM:'13',RR:'14',PA:'15',AP:'16',TO:'17',MA:'21',PI:'22',CE:'23',RN:'24',PB:'25',PE:'26',AL:'27',SE:'28',BA:'29',MG:'31',ES:'32',RJ:'33',SP:'35',PR:'41',SC:'42',RS:'43',MS:'50',MT:'51',GO:'52',DF:'53'});
const CSOSN=new Set(['101','102','103','201','202','203','300','400','500','900']);

export function validatePilotFiscalConfig(input={}){
  const result=evaluatePilotPreflight(input);
  const blockers=[...result.blockers];
  if(input.state&&input.stateCode&&UF_CODES[input.state]!==input.stateCode)blockers.push('stateCodeMismatch');
  if(input.municipalityCode&&input.stateCode&&!input.municipalityCode.startsWith(input.stateCode))blockers.push('municipalityStateMismatch');
  if(input.stateRegistration&&!/^\d{2,14}$/.test(input.stateRegistration))blockers.push('stateRegistrationFormat');
  if(input.cfop&&!/^[567]\d{3}$/.test(input.cfop))blockers.push('cfopDirection');
  if(input.csosn&&!CSOSN.has(input.csosn))blockers.push('csosnUnsupported');
  return Object.freeze({...result,ready:blockers.length===0,blockers:Object.freeze([...new Set(blockers)])});
}

export const pilotUfCodes=UF_CODES;
