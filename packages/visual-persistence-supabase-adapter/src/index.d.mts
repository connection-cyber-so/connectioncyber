export type Json=null|boolean|number|string|Json[]|{[key:string]:Json};
export interface SupabaseLike{rpc(name:string,args:Record<string,unknown>):Promise<{data:Json|undefined;error:{code?:string}|null}>;from(table:string):unknown;}
export interface ReadContract{key:string;screen:string;source:string;tenantFilter:'server-resolved';empty:string;}
export interface SupabasePersistenceTransport{rpc(name:string,args:{p_tenant_id:string;p_request_id:string;p_payload_hash:string;p_payload:Record<string,Json>}):Promise<Json>;read(contract:ReadContract,tenantId:string):Promise<Json>;}
export function createSupabasePersistenceTransport(options:{client:SupabaseLike;aggregateReader?:((input:{client:SupabaseLike;tenantId:string;scope:'dashboard'|'finance'})=>Promise<Json>)}):SupabasePersistenceTransport;
export const READ_PLANS:Readonly<Record<string,Readonly<Record<string,unknown>>>>;export const RPC_ALLOWLIST:readonly string[];
export function createSupabaseAggregateReader():((input:{client:SupabaseLike;tenantId:string;scope:'dashboard'|'finance'})=>Promise<Json>);
export const AGGREGATE_LIMIT:number;
export function normalizeReadModel(key:string,value:Json,tenantId:string):Json;
