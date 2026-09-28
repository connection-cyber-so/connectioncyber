import{evaluatePilotPreflight}from'../src/pilot-preflight.mjs';
const result=evaluatePilotPreflight({pilotId:'pilot-maniademoda',environment:'homologation'});
console.log(JSON.stringify({result:'M13_G17_PREFLIGHT_BLOCKED',ready:result.ready,blockers:result.blockers,xmlGenerated:result.xmlGenerated,signed:result.signed,persisted:result.persisted,transmitted:result.transmitted,productionAccessed:result.productionAccessed}));
