import {validateTenantTaxProfile} from '../src/tax-profiles.mjs';
const result=validateTenantTaxProfile({tenantId:'tenant-synthetic-rpa',profileCode:'NORMAL_RPA',declaredCrt:'3',taxCodeKind:'CST',taxCode:'00',ncm:'61091000',cfop:'5102',environment:'homologation',ruleSetVersion:'NFE_4.00_2026.06',accountantApproved:true});
console.log(JSON.stringify({result:result.ready?'M13_G19_SYNTHETIC_PROFILES_OK':'M13_G19_SYNTHETIC_PROFILES_BLOCKED',...result,syntheticOnly:true}));
if(!result.ready)process.exitCode=1;
