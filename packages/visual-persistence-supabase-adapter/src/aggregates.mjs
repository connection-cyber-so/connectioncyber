const AGGREGATE_LIMIT=5000;
const fail=(code,message=code)=>{const error=new Error(message);error.code=code;throw error;};
const number=value=>{const parsed=Number(value);return Number.isFinite(parsed)?parsed:0;};
const assertTenant=tenantId=>{if(typeof tenantId!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(tenantId))fail('TENANT_UNRESOLVED');};
async function rows(client,tenantId,{table,columns,eq,eqs=[],in:inFilter}){let query=client.from(table).select(columns).eq('tenant_id',tenantId);for(const filter of eq?[eq,...eqs]:eqs)query=query.eq(...filter);if(inFilter)query=query.in(...inFilter);query=query.limit(AGGREGATE_LIMIT);const{data,error}=await query;if(error)fail(typeof error.code==='string'?error.code:'PERSISTENCE_FAILURE','aggregate read failed');if(!Array.isArray(data))fail('INVALID_PERSISTENCE_RESPONSE');if(data.length===AGGREGATE_LIMIT)fail('AGGREGATE_LIMIT_EXCEEDED');return data;}
const sum=(items,key)=>items.reduce((total,row)=>total+number(row[key]),0);
export function createSupabaseAggregateReader(){return async({client,tenantId,scope})=>{assertTenant(tenantId);
 if(scope==='finance'){
  const[entries,installments]=await Promise.all([
   rows(client,tenantId,{table:'erp_financial_entries',columns:'id,direction,status,principal_amount',in:['status',['open','partially_settled','settled']]}),
   rows(client,tenantId,{table:'erp_installments',columns:'id,financial_entry_id,status,principal_amount,interest_amount,fine_amount,discount_amount',in:['status',['open','partially_settled','settled','overdue']]})
  ]);
  const openEntries=entries.filter(row=>row.status==='open'||row.status==='partially_settled');
  return Object.freeze({scope:'finance',receivablePrincipal:sum(entries.filter(row=>row.direction==='receivable'),'principal_amount'),payablePrincipal:sum(entries.filter(row=>row.direction==='payable'),'principal_amount'),openReceivablePrincipal:sum(openEntries.filter(row=>row.direction==='receivable'),'principal_amount'),openPayablePrincipal:sum(openEntries.filter(row=>row.direction==='payable'),'principal_amount'),openInstallments:installments.filter(row=>row.status!=='settled').length,overdueInstallments:installments.filter(row=>row.status==='overdue').length});
 }
 if(scope!=='dashboard')fail('ADAPTER_READ_BLOCKED');
 const[customers,items,stock,sales,cash,entries,allocations]=await Promise.all([
  rows(client,tenantId,{table:'erp_party_roles',columns:'party_id',eq:['role','customer'],eqs:[['active',true]]}),rows(client,tenantId,{table:'erp_catalog_items',columns:'id',eq:['status','active']}),rows(client,tenantId,{table:'erp_stock_movement_items',columns:'quantity_delta'}),rows(client,tenantId,{table:'erp_sales',columns:'id,grand_total',eq:['status','completed']}),rows(client,tenantId,{table:'erp_cash_sessions',columns:'id',in:['status',['open','closing']]}),rows(client,tenantId,{table:'erp_financial_entries',columns:'direction,status,principal_amount',eq:['source_type','sale']}),rows(client,tenantId,{table:'erp_settlement_allocations',columns:'allocated_amount,erp_settlements(status),erp_installments(erp_financial_entries(direction))'})
 ]);
 const salesTotal=sum(sales,'grand_total'),receivables=sum(entries.filter(row=>row.direction==='receivable'),'principal_amount'),settled=allocations.filter(row=>row.erp_settlements?.status==='confirmed'&&row.erp_installments?.erp_financial_entries?.direction==='receivable').reduce((total,row)=>total+number(row.allocated_amount),0),cashSales=salesTotal-receivables;
 if(cashSales<0||settled>receivables)fail('INVALID_PERSISTENCE_RESPONSE');
 return Object.freeze({customers:customers.length,products:items.length,stockUnits:sum(stock,'quantity_delta'),salesCount:sales.length,salesTotal,cashSales,receivables,settled,openReceivables:receivables-settled,cashStatus:cash.length?'open':'closed',balanced:salesTotal===cashSales+receivables});
};}
export{AGGREGATE_LIMIT};
