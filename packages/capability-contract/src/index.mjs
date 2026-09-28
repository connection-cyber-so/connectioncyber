import { createHash } from 'node:crypto'

export const CAPABILITIES=Object.freeze(['parties','catalog','sales','cash','finance','inventory','services','restaurant','remote_support','device_agent','fiscal','legacy_import'])
export const PLAN_BLUEPRINTS=Object.freeze({
  MEI:Object.freeze(['parties','catalog','sales','cash','finance']),
  ME:Object.freeze(['parties','catalog','sales','cash','finance','inventory','services']),
  LTDA:Object.freeze(['parties','catalog','sales','cash','finance','inventory','services','restaurant','remote_support','device_agent','fiscal','legacy_import'])
})

const CAPABILITY_SET=new Set(CAPABILITIES),PROFILE_SET=new Set(Object.keys(PLAN_BLUEPRINTS))
const fail=code=>{throw new Error(code)}
const canonical=value=>Array.isArray(value)?value.map(canonical):value&&typeof value==='object'?Object.fromEntries(Object.keys(value).sort().map(key=>[key,canonical(value[key])])):value
const stable=value=>JSON.stringify(canonical(value))
const hash=value=>createHash('sha256').update(stable(value)).digest('hex')
const assertSynthetic=value=>{const text=JSON.stringify(value);if(!text.includes('SYNTHETIC')||/cnpj|cpf|password|secret|certificate|csc|@/i.test(text))fail('REAL_OR_SECRET_DATA_FORBIDDEN')}

export function validateCapabilityManifest(manifest){
  assertSynthetic(manifest)
  if(manifest.version!==1)fail('UNSUPPORTED_MANIFEST_VERSION')
  if(!/^SYNTHETIC-TENANT-[A-Z0-9-]+$/.test(manifest.tenantId??''))fail('INVALID_SYNTHETIC_TENANT')
  if(!PROFILE_SET.has(manifest.legalProfile))fail('UNKNOWN_LEGAL_PROFILE')
  if(!Array.isArray(manifest.exceptions))fail('INVALID_EXCEPTIONS')
  const ids=new Set()
  for(const exception of manifest.exceptions){
    if(!/^SYNTHETIC-EX-[A-Z0-9-]+$/.test(exception.id??'')||ids.has(exception.id))fail('INVALID_EXCEPTION_ID')
    ids.add(exception.id)
    if(!CAPABILITY_SET.has(exception.capability))fail('UNKNOWN_CAPABILITY')
    if(!['allow','deny'].includes(exception.effect))fail('INVALID_EXCEPTION_EFFECT')
    if(typeof exception.reason!=='string'||!exception.reason.startsWith('SYNTHETIC-'))fail('INVALID_EXCEPTION_REASON')
    if(!/^SYNTHETIC-APPROVER-[A-Z0-9-]+$/.test(exception.approvedBy??''))fail('INVALID_EXCEPTION_APPROVER')
    if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000Z$/.test(exception.expiresAt??''))fail('INVALID_EXCEPTION_EXPIRY')
  }
  return true
}

export function resolveCapabilities(manifest,{now='2026-08-30T12:00:00.000Z'}={}){
  validateCapabilityManifest(manifest)
  const enabled=new Set(PLAN_BLUEPRINTS[manifest.legalProfile]),applied=[],expired=[],denied=new Set()
  const ordered=[...manifest.exceptions].sort((a,b)=>a.id.localeCompare(b.id))
  for(const exception of ordered){
    if(exception.expiresAt<=now){expired.push(exception.id);continue}
    if(exception.effect==='deny'){denied.add(exception.capability);enabled.delete(exception.capability);applied.push(exception.id);continue}
    if(denied.has(exception.capability)){applied.push(exception.id);continue}
    enabled.add(exception.capability);applied.push(exception.id)
  }
  for(const capability of denied)enabled.delete(capability)
  const capabilities=CAPABILITIES.map(capability=>Object.freeze({capability,enabled:enabled.has(capability),source:enabled.has(capability)?(ordered.some(item=>item.capability===capability&&item.effect==='allow'&&item.expiresAt>now)?'exception':'blueprint'):'deny'}))
  const evidence=Object.freeze({tenantId:manifest.tenantId,legalProfile:manifest.legalProfile,manifestVersion:manifest.version,applied:Object.freeze(applied),expired:Object.freeze(expired),capabilities:Object.freeze(capabilities)})
  return Object.freeze({...evidence,auditHash:hash(evidence),remoteAccessed:false,productionAccessed:false})
}

export function isCapabilityEnabled(resolution,capability){
  if(!CAPABILITY_SET.has(capability))return false
  return resolution.capabilities.some(item=>item.capability===capability&&item.enabled===true)
}

export function executeSyntheticCapabilitySimulation(){
  const manifests=['MEI','ME','LTDA'].map((legalProfile,index)=>({version:1,tenantId:`SYNTHETIC-TENANT-${index+1}`,legalProfile,exceptions:[]}))
  const resolutions=manifests.map(manifest=>resolveCapabilities(manifest))
  const exception=resolveCapabilities({version:1,tenantId:'SYNTHETIC-TENANT-EXCEPTION',legalProfile:'ME',exceptions:[{id:'SYNTHETIC-EX-DENY-FINANCE',capability:'finance',effect:'deny',reason:'SYNTHETIC-CONTRACT-SCOPE',approvedBy:'SYNTHETIC-APPROVER-SECURITY',expiresAt:'2027-01-01T00:00:00.000Z'}]})
  return Object.freeze({result:'M16_G1_CAPABILITY_CONTRACT_OK',profiles:resolutions.map(item=>item.legalProfile),meiInventory:isCapabilityEnabled(resolutions[0],'inventory'),meInventory:isCapabilityEnabled(resolutions[1],'inventory'),ltdaFiscal:isCapabilityEnabled(resolutions[2],'fiscal'),exceptionFinance:isCapabilityEnabled(exception,'finance'),remoteAccessed:false,productionAccessed:false})
}
