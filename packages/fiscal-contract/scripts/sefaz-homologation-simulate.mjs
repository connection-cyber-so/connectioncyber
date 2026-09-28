import{createSefazHomologationAdapter,maniaDeModaSyntheticRequest}from'../src/sefaz-homologation.mjs';
const result=await createSefazHomologationAdapter().simulate(maniaDeModaSyntheticRequest());console.log(JSON.stringify({result:'SEFAZ_HOMOLOGATION_SIMULATION_OK',status:result.response.status,networkCall:result.networkCall,fiscalValue:result.fiscalValue,xmlHash:result.signature.xmlHash}));
