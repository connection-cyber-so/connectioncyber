import { buildSyntheticProfileMatrix } from '../src/engine.mjs'
const result=buildSyntheticProfileMatrix()
const ltda=result.rows.find(row=>row.legalProfile==='LTDA'),mei=result.rows.find(row=>row.legalProfile==='MEI')
if(result.rows.length!==3||mei.states.inventory!=='disabled'||ltda.states.fiscal!=='blocked'||ltda.states.sales!=='enabled')throw new Error('M16_G2_FAIL_CLOSED_ENGINE_FAILED')
console.log(JSON.stringify(result))
