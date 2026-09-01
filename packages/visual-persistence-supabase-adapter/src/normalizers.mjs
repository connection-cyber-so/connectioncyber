const fail=(code)=>{const error=new Error(code);error.code=code;throw error;};
const amount=value=>{const parsed=Number(value);if(!Number.isFinite(parsed))fail('INVALID_PERSISTENCE_RESPONSE');return parsed;};
const rows=value=>{if(!Array.isArray(value))fail('INVALID_PERSISTENCE_RESPONSE');return value;};
const tenantRows=(value,tenantId)=>rows(value).map(row=>{if(!row||typeof row!=='object'||row.tenant_id!==tenantId)fail('ACCESS_DENIED');return row;});
const nested=value=>value==null?[]:Array.isArray(value)?value:[value];
const confirmedAllocated=entry=>nested(entry.erp_installments).flatMap(row=>nested(row.erp_settlement_allocations)).filter(row=>nested(row.erp_settlements).some(settlement=>settlement.status==='confirmed')).reduce((total,row)=>total+amount(row.allocated_amount),0);
export function normalizeReadModel(key,value,tenantId){
 const source=tenantRows(value,tenantId);
 if(key==='parties'||key==='catalog-items'||key==='stock-movements')return structuredClone(source);
 if(key==='stock-balance')return source.map(row=>{const item=nested(row.erp_catalog_items)[0];if(!item?.code||!item?.name)fail('INVALID_PERSISTENCE_RESPONSE');return{itemId:String(row.item_id),code:String(item.code),name:String(item.name),quantity:amount(row.quantity)};});
 if(key==='open-cash-sessions'||key==='cash-history')return source.map(row=>({id:String(row.id),status:String(row.status),openingAmount:amount(row.opening_amount),expectedAmount:amount(row.expected_amount??row.opening_amount),openedAt:String(row.opened_at),closedAt:row.closed_at?String(row.closed_at):null,countedAmount:row.counted_amount==null?null:amount(row.counted_amount)}));
 if(key==='sales')return source.map(row=>{const saleItems=nested(row.erp_sale_items),payments=nested(row.erp_sale_payments),kinds=[...new Set(payments.flatMap(payment=>nested(payment.erp_payment_methods).map(method=>method.kind)))];return{id:String(row.id),code:String(row.code),itemName:saleItems.length===1?String(nested(saleItems[0].erp_catalog_items)[0]?.name??'Item'):`${saleItems.length} itens`,quantity:saleItems.reduce((total,item)=>total+amount(item.quantity),0),total:amount(row.grand_total),paymentKind:kinds.length===1?String(kinds[0]):'mixed',createdAt:String(row.completed_at??row.created_at)};});
 if(key==='financial-entries')return source.map(row=>{const total=amount(row.principal_amount),settled=confirmedAllocated(row);if(settled>total)fail('INVALID_PERSISTENCE_RESPONSE');return{id:String(row.id),code:String(row.code),customerName:String(nested(row.erp_parties)[0]?.legal_name??'Sem parte vinculada'),total,settled,status:String(row.status)};});
 if(key==='installments')return source.map(row=>({id:String(row.id),financialEntryId:String(row.financial_entry_id),number:Number(row.number),status:String(row.status),dueDate:String(row.due_date),principalAmount:amount(row.principal_amount),interestAmount:amount(row.interest_amount),fineAmount:amount(row.fine_amount),discountAmount:amount(row.discount_amount)}));
 fail('ADAPTER_READ_BLOCKED');
}
