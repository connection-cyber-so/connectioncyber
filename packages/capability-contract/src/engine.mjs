import { CAPABILITIES, isCapabilityEnabled, resolveCapabilities } from './index.mjs'

export const CAPABILITY_DEPENDENCIES=Object.freeze({
  parties:Object.freeze([]),catalog:Object.freeze([]),
  sales:Object.freeze(['parties','catalog']),cash:Object.freeze(['sales']),finance:Object.freeze(['cash']),
  inventory:Object.freeze(['catalog']),services:Object.freeze(['parties','catalog']),
  restaurant:Object.freeze(['sales','inventory']),remote_support:Object.freeze([]),device_agent:Object.freeze([]),
  fiscal:Object.freeze(['sales','catalog']),legacy_import:Object.freeze(['parties','catalog'])
})
export const READINESS_REQUIREMENTS=Object.freeze({remote_support:'consentReady',device_agent:'deviceReady',fiscal:'fiscalValidated',legacy_import:'sourceValidated'})
const READINESS_KEYS=new Set(Object.values(READINESS_REQUIREMENTS))
const fail=code=>{throw new Error(code)}

function validateReadiness(readiness){
  if(!readiness||typeof readiness!=='object'||Array.isArray(readiness))fail('INVALID_READINESS')
  for(const [key,value] of Object.entries(readiness)){
    if(!READINESS_KEYS.has(key))fail('UNKNOWN_READINESS_KEY')
    if(typeof value!=='boolean')fail('INVALID_READINESS_VALUE')
  }
}

export function resolveOperationalCapabilities(manifest,{now='2026-08-30T12:00:00.000Z',readiness={}}={}){
  validateReadiness(readiness)
  const contract=resolveCapabilities(manifest,{now}),states=[]
  for(const capability of CAPABILITIES){
    if(!isCapabilityEnabled(contract,capability)){states.push(Object.freeze({capability,status:'disabled',reason:'CONTRACT_DENY'}));continue}
    const missingDependency=CAPABILITY_DEPENDENCIES[capability].find(dependency=>states.find(item=>item.capability===dependency)?.status!=='enabled')
    if(missingDependency){states.push(Object.freeze({capability,status:'blocked',reason:`DEPENDENCY_${missingDependency.toUpperCase()}_NOT_ENABLED`}));continue}
    const requirement=READINESS_REQUIREMENTS[capability]
    if(requirement&&readiness[requirement]!==true){states.push(Object.freeze({capability,status:'blocked',reason:`READINESS_${requirement.toUpperCase()}_REQUIRED`}));continue}
    states.push(Object.freeze({capability,status:'enabled',reason:'READY'}))
  }
  return Object.freeze({tenantId:contract.tenantId,legalProfile:contract.legalProfile,contractHash:contract.auditHash,states:Object.freeze(states),remoteAccessed:false,productionAccessed:false})
}

export function capabilityStatus(resolution,capability){
  return resolution.states.find(item=>item.capability===capability)??Object.freeze({capability,status:'blocked',reason:'UNKNOWN_CAPABILITY'})
}

export function buildSyntheticProfileMatrix(){
  const readiness={consentReady:false,deviceReady:false,fiscalValidated:false,sourceValidated:false}
  const profiles=['MEI','ME','LTDA'].map((legalProfile,index)=>resolveOperationalCapabilities({version:1,tenantId:`SYNTHETIC-TENANT-MATRIX-${index+1}`,legalProfile,exceptions:[]},{readiness}))
  return Object.freeze({result:'M16_G2_FAIL_CLOSED_ENGINE_OK',columns:Object.freeze(CAPABILITIES),rows:Object.freeze(profiles.map(item=>Object.freeze({legalProfile:item.legalProfile,states:Object.freeze(Object.fromEntries(item.states.map(state=>[state.capability,state.status])))}))),remoteAccessed:false,productionAccessed:false})
}
