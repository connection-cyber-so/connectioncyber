import{defineA1CustodyPolicy,maniaDeModaPilotDescriptor,validatePilotDescriptor}from'../src/custody.mjs';
const pilot=validatePilotDescriptor(maniaDeModaPilotDescriptor());
const custody=defineA1CustodyPolicy({storage:'external-vault',privateKeyExportable:false,gitStorage:false,databaseStorage:false,importAuthorized:false,signingAuthorized:false,transmissionAuthorized:false,requiredApprovals:['certificate-import','fiscal-transmission']});
console.log(JSON.stringify({result:'M13_G6_LOCAL_VALIDATION_OK',pilotId:pilot.pilotId,environment:pilot.environment,certificateImported:custody.importAuthorized,signingEnabled:custody.signingAuthorized,transmissionEnabled:custody.transmissionAuthorized,productionEnabled:pilot.productionEnabled}));
