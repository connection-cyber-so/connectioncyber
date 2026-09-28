const CST=new Set(['00','10','20','30','40','41','50','51','60','70','90']);
const CSOSN=new Set(['101','102','103','201','202','203','300','400','500','900']);

export const TAX_PROFILES=Object.freeze({
  NORMAL_RPA:Object.freeze({crt:'3',taxCodeKind:'CST',released:true}),
  SIMPLE_NATIONAL:Object.freeze({crt:'1',taxCodeKind:'CSOSN',released:true}),
  SIMPLE_EXCESS:Object.freeze({crt:'2',taxCodeKind:'CST',released:true}),
  MEI:Object.freeze({crt:'4',taxCodeKind:'CSOSN',released:false})
});

export function validateTenantTaxProfile(input={}){
  const blockers=[];
  const profile=TAX_PROFILES[input.profileCode];
  if(!/^tenant-[a-z0-9-]+$/.test(input.tenantId??''))blockers.push('tenantRequired');
  if(!profile)blockers.push('profileUnknown');
  if(profile&&input.declaredCrt!==profile.crt)blockers.push('crtMismatch');
  if(profile&&input.taxCodeKind!==profile.taxCodeKind)blockers.push('taxCodeKindMismatch');
  if(input.taxCodeKind==='CST'&&!CST.has(input.taxCode))blockers.push('cstUnsupported');
  if(input.taxCodeKind==='CSOSN'&&!CSOSN.has(input.taxCode))blockers.push('csosnUnsupported');
  if(!/^\d{8}$/.test(input.ncm??''))blockers.push('ncmInvalid');
  if(!/^[567]\d{3}$/.test(input.cfop??''))blockers.push('cfopInvalid');
  if(input.environment!=='homologation')blockers.push('productionForbidden');
  if(input.ruleSetVersion!=='NFE_4.00_2026.06')blockers.push('ruleSetUnpinned');
  if(input.accountantApproved!==true)blockers.push('accountantApprovalRequired');
  if(profile&&!profile.released)blockers.push('profileNotReleased');
  return Object.freeze({ready:blockers.length===0,blockers:Object.freeze([...new Set(blockers)]),tenantId:input.tenantId??null,profileCode:input.profileCode??null,xmlGenerated:false,signed:false,persisted:false,transmitted:false,productionAccessed:false});
}

export function resolveTenantTaxProfile(bindings,tenantId){
  const own=bindings.find(binding=>binding.tenantId===tenantId);
  if(!own)throw new Error('TENANT_TAX_PROFILE_NOT_FOUND');
  return Object.freeze({...own});
}
