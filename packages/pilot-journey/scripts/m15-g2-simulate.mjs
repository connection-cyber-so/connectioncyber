import { executeSyntheticJourney } from '../src/index.mjs'
const result=executeSyntheticJourney()
if(!result.crossTenantDenied||!result.fiscalFailClosed||result.afterRollback.records!==0)throw new Error('M15_G2_SYNTHETIC_JOURNEY_FAILED')
console.log(JSON.stringify(result))
