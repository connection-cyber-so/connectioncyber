import { executeSyntheticCapabilitySimulation } from '../src/index.mjs'
const result=executeSyntheticCapabilitySimulation()
if(result.meiInventory||!result.meInventory||!result.ltdaFiscal||result.exceptionFinance)throw new Error('M16_G1_CAPABILITY_CONTRACT_FAILED')
console.log(JSON.stringify(result))
