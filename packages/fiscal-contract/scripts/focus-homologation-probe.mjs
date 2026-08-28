import{createFocusHomologationAdapter,syntheticFocusProbe}from'../src/focus-homologation.mjs';
const token=process.env.FOCUS_NFE_HOMOLOGATION_TOKEN;
if(!token){console.error('FOCUS_HOMOLOGATION_BLOCKED: configure FOCUS_NFE_HOMOLOGATION_TOKEN');process.exit(2)}
const adapter=createFocusHomologationAdapter({token});
const prepared=adapter.prepareIssue(syntheticFocusProbe());
console.log(JSON.stringify({result:'FOCUS_HOMOLOGATION_READY',environment:adapter.environment,reference:prepared.reference,payloadHash:prepared.payloadHash,networkCall:false}));
