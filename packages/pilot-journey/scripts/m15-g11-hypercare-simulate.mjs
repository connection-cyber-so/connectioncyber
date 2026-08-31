import { executeSyntheticHypercare } from '../src/index.mjs'
const result=executeSyntheticHypercare()
if(result.healthy!=='HEALTHY'||result.degraded!=='SEV-2'||result.critical!=='SEV-1'||!result.acceptanceBlocked)throw new Error('M15_G11_LOCAL_PREPARATION_FAILED')
console.log(JSON.stringify(result))
