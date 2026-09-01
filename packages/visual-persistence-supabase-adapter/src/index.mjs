const RPC_ALLOWLIST=Object.freeze(['erp_command_create_party_v1','erp_command_create_catalog_item_v1','erp_command_receive_inventory_v1','erp_command_open_cash_v1','erp_command_complete_sale_v1','erp_command_settle_receivable_v1','erp_command_close_cash_v1']);
const RPC_NAMES=new Set(RPC_ALLOWLIST);
const READ_PLANS=Object.freeze({
 'erp_parties:/cadastros':{table:'erp_parties',columns:'id,tenant_id,kind,legal_name,trade_name,tax_id,active,created_at,erp_party_roles(role,active)',order:['created_at',{ascending:false}],limit:100},
 'erp_catalog_items:/catalogo':{table:'erp_catalog_items',columns:'id,tenant_id,kind,code,name,description,track_inventory,allows_fraction,status,erp_units(code,name)',order:['name',{ascending:true}],limit:100},
 'erp_stock_balance_v:/operacoes':{table:'erp_stock_movement_items',columns:'tenant_id,location_id,item_id,variant_id,quantity_delta',order:['item_id',{ascending:true}],limit:1000,transform:'stock-balance'},
 'erp_stock_movements:/operacoes':{table:'erp_stock_movements',columns:'id,tenant_id,type,status,occurred_at,posted_at',order:['occurred_at',{ascending:false}],limit:100},
 'erp_cash_sessions:/pdv:open':{table:'erp_cash_sessions',columns:'id,tenant_id,status,opened_at,closed_at,opening_amount,expected_amount,counted_amount,difference_amount',in:['status',['open','closing']],order:['opened_at',{ascending:false}],limit:20},
 'erp_cash_sessions:/pdv:history':{table:'erp_cash_sessions',columns:'id,tenant_id,status,opened_at,closed_at,opening_amount,expected_amount,counted_amount,difference_amount',eq:['status','closed'],order:['closed_at',{ascending:false}],limit:50},
 'erp_sales:/vendas':{table:'erp_sales',columns:'id,tenant_id,code,status,customer_id,grand_total,currency_code,completed_at,created_at',order:['created_at',{ascending:false}],limit:100},
 'erp_financial_entries:/financeiro':{table:'erp_financial_entries',columns:'id,tenant_id,party_id,code,direction,status,principal_amount,currency_code,due_date,source_type,source_id',order:['due_date',{ascending:true}],limit:100},
 'erp_installments:/financeiro':{table:'erp_installments',columns:'id,tenant_id,financial_entry_id,number,status,due_date,principal_amount,interest_amount,fine_amount,discount_amount',order:['due_date',{ascending:true}],limit:200}
});
const fail=(code,message=code)=>{const error=new Error(message);error.code=code;throw error;};
const readKey=contract=>{if(contract.key==='open-cash-sessions')return'erp_cash_sessions:/pdv:open';if(contract.key==='cash-history')return'erp_cash_sessions:/pdv:history';return `${contract.source}:${contract.screen}`;};
const assertTenant=tenantId=>{if(typeof tenantId!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId))fail('TENANT_UNRESOLVED');};
const stockBalance=rows=>Array.from(rows.reduce((map,row)=>{const key=`${row.location_id}:${row.item_id}:${row.variant_id??''}`,current=map.get(key)??{tenant_id:row.tenant_id,location_id:row.location_id,item_id:row.item_id,variant_id:row.variant_id,quantity:0};current.quantity+=Number(row.quantity_delta);map.set(key,current);return map;},new Map()).values());
export function createSupabasePersistenceTransport({client,aggregateReader}={}){
 if(!client?.rpc||!client?.from)fail('INVALID_ADAPTER_DEPENDENCY');
 return Object.freeze({
  async rpc(rpc,args){if(!RPC_NAMES.has(rpc))fail('ADAPTER_RPC_BLOCKED');assertTenant(args?.p_tenant_id);const{data,error}=await client.rpc(rpc,args);if(error)fail(typeof error.code==='string'?error.code:'PERSISTENCE_FAILURE','persistence command failed');if(data===undefined||data===null)fail('INVALID_PERSISTENCE_RESPONSE');return data;},
  async read(contract,tenantId){assertTenant(tenantId);if(contract?.tenantFilter!=='server-resolved')fail('ADAPTER_READ_BLOCKED');if(contract.source==='server-aggregate'){if(typeof aggregateReader!=='function')fail('ADAPTER_NOT_CONFIGURED');return aggregateReader({client,tenantId,scope:contract.screen==='/'?'dashboard':'finance'});}const plan=READ_PLANS[readKey(contract)];if(!plan)fail('ADAPTER_READ_BLOCKED');let query=client.from(plan.table).select(plan.columns).eq('tenant_id',tenantId);if(plan.eq)query=query.eq(...plan.eq);if(plan.in)query=query.in(...plan.in);if(plan.order)query=query.order(...plan.order);if(plan.limit)query=query.limit(plan.limit);const{data,error}=await query;if(error)fail(typeof error.code==='string'?error.code:'PERSISTENCE_FAILURE','persistence read failed');if(!Array.isArray(data))fail('INVALID_PERSISTENCE_RESPONSE');return plan.transform==='stock-balance'?stockBalance(data):data;}
 });
}
export{READ_PLANS,RPC_ALLOWLIST};
export{createSupabaseAggregateReader,AGGREGATE_LIMIT}from'./aggregates.mjs';
