import { POSTGRES_CONTRACT_VERSION, RELEASE_GATES, RPC_CONTRACTS, validatePostgresPersistenceContract } from '../src/postgres-persistence-contract.mjs';

const result = validatePostgresPersistenceContract();
if (!result.valid) throw new Error(`M17_G7_CONTRACT_INVALID:${result.findings.join(',')}`);
console.log(JSON.stringify({ result: 'M17_G7_POSTGRES_PERSISTENCE_CONTRACT_OK', version: POSTGRES_CONTRACT_VERSION, rpcCount: Object.keys(RPC_CONTRACTS).length, releaseGates: RELEASE_GATES.length, ...result }));
