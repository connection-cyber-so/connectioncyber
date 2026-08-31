const freeze=value=>{if(value&&typeof value==='object'&&!Object.isFrozen(value)){Object.freeze(value);for(const nested of Object.values(value))freeze(nested);}return value;};
export const CONTRACT_VERSION='M18-VISUAL-1.0';
export const COMMAND_BOUNDARIES=freeze({
 'party.create':{rpc:'erp_command_create_party_v1',screen:'/cadastros',refresh:['parties'],success:'party-created'},
 'catalog.item.create':{rpc:'erp_command_create_catalog_item_v1',screen:'/catalogo',refresh:['catalog-items'],success:'catalog-item-created'},
 'inventory.receive':{rpc:'erp_command_receive_inventory_v1',screen:'/operacoes',refresh:['stock-balance','stock-movements'],success:'inventory-received'},
 'cash.open':{rpc:'erp_command_open_cash_v1',screen:'/pdv',refresh:['open-cash-sessions'],success:'cash-opened'},
 'sale.complete':{rpc:'erp_command_complete_sale_v1',screen:'/pdv',refresh:['sales','stock-balance','open-cash-sessions','financial-summary'],success:'sale-completed'},
 'finance.receivable.settle':{rpc:'erp_command_settle_receivable_v1',screen:'/financeiro',refresh:['financial-entries','installments','financial-summary'],success:'receivable-settled'},
 'cash.close':{rpc:'erp_command_close_cash_v1',screen:'/pdv',refresh:['open-cash-sessions','cash-history','dashboard-summary'],success:'cash-closed'},
});
export const READ_MODELS=freeze({
 parties:{screen:'/cadastros',source:'erp_parties',tenantFilter:'server-resolved',empty:'Nenhum cliente cadastrado.'},
 'catalog-items':{screen:'/catalogo',source:'erp_catalog_items',tenantFilter:'server-resolved',empty:'Nenhum produto cadastrado.'},
 'stock-balance':{screen:'/operacoes',source:'erp_stock_balance_v',tenantFilter:'server-resolved',empty:'Nenhum saldo de estoque.'},
 'stock-movements':{screen:'/operacoes',source:'erp_stock_movements',tenantFilter:'server-resolved',empty:'Nenhuma movimentação.'},
 'open-cash-sessions':{screen:'/pdv',source:'erp_cash_sessions',tenantFilter:'server-resolved',empty:'Nenhum caixa aberto.'},
 sales:{screen:'/vendas',source:'erp_sales',tenantFilter:'server-resolved',empty:'Nenhuma venda concluída.'},
 'financial-entries':{screen:'/financeiro',source:'erp_financial_entries',tenantFilter:'server-resolved',empty:'Nenhum título financeiro.'},
 installments:{screen:'/financeiro',source:'erp_installments',tenantFilter:'server-resolved',empty:'Nenhuma parcela.'},
 'financial-summary':{screen:'/financeiro',source:'server-aggregate',tenantFilter:'server-resolved',empty:'Financeiro sem movimento.'},
 'cash-history':{screen:'/pdv',source:'erp_cash_sessions',tenantFilter:'server-resolved',empty:'Nenhum fechamento.'},
 'dashboard-summary':{screen:'/',source:'server-aggregate',tenantFilter:'server-resolved',empty:'Operação sem movimento.'},
});
export const UX_STATES=freeze(['idle','validating','submitting','revalidating','succeeded','failed','blocked']);
export const UX_TRANSITIONS=freeze({idle:['validating'],validating:['submitting','failed','blocked'],submitting:['revalidating','failed','blocked'],revalidating:['succeeded','failed'],succeeded:['idle'],failed:['idle'],blocked:['idle']});
export const AUTHORITY_FIELDS=freeze(['tenant_id','tenantId','actor_id','actorId','user_id','userId','permission','permissions','capability','capabilities','role','priceTotal','grandTotal','stockBalance','cashExpected','financialBalance']);
export const SECRET_FIELDS=freeze(['password','senha','secret','token','credential','privateKey','private_key','serviceRole','service_role','certificate','certificado','pfx','p12','csc']);
export const PUBLIC_ERRORS=freeze({AUTH_REQUIRED:'Entre novamente para continuar.',TENANT_UNRESOLVED:'Não foi possível identificar a empresa.',ACCESS_DENIED:'Você não tem acesso a esta operação.',CAPABILITY_REQUIRED:'Este recurso não está habilitado para a empresa.',IDEMPOTENCY_CONFLICT:'A solicitação já existe com conteúdo diferente.',INVALID_INPUT:'Revise os campos informados.',INVALID_STATE:'A operação não é permitida no estado atual.',TEMPORARY_FAILURE:'Não foi possível concluir agora. Verifique o estado antes de tentar novamente.',INTERNAL_FAILURE:'Não foi possível concluir a operação.'});
export const THREAT_MODEL=freeze([
 {id:'T01',threat:'tenant supplied by browser',control:'resolve-host-membership-server-side',test:'authority-field-rejected'},
 {id:'T02',threat:'price or balance tampering',control:'derive-authoritative-values-in-rpc',test:'authority-field-rejected'},
 {id:'T03',threat:'duplicate submit or network retry',control:'stable-request-id-and-payload-hash',test:'same-request-replay'},
 {id:'T04',threat:'cross-tenant stale tab',control:'re-resolve-tenant-on-every-command',test:'stale-context-blocked'},
 {id:'T05',threat:'sql detail disclosure',control:'stable-public-error-map',test:'unsafe-error-redacted'},
 {id:'T06',threat:'optimistic state becomes authority',control:'mandatory-post-command-revalidation',test:'success-requires-revalidation'},
 {id:'T07',threat:'blind automatic write retry',control:'browser-write-retry-disabled',test:'failure-requires-state-check'},
 {id:'T08',threat:'secret reaches payload or telemetry',control:'recursive-secret-screening',test:'secret-field-rejected'},
 {id:'T09',threat:'double click while submitting',control:'single-flight-by-request-id',test:'submitting-is-not-reentrant'},
 {id:'T10',threat:'stale read after mutation',control:'refresh-contract-per-command',test:'every-command-refreshes'},
]);
const walkKeys=(value,visit)=>{if(!value||typeof value!=='object')return;for(const[key,nested]of Object.entries(value)){visit(key);walkKeys(nested,visit);}};
export function validateBrowserPayload(payload){if(!payload||typeof payload!=='object'||Array.isArray(payload))throw new Error('INVALID_INPUT');const forbidden=new Set([...AUTHORITY_FIELDS,...SECRET_FIELDS].map(key=>key.toLowerCase()));walkKeys(payload,key=>{if(forbidden.has(key.toLowerCase()))throw new Error('FORBIDDEN_BROWSER_FIELD');});if(Buffer.byteLength(JSON.stringify(payload),'utf8')>65536)throw new Error('PAYLOAD_TOO_LARGE');return true;}
export function transitionUx(current,next){if(!UX_STATES.includes(current)||!UX_STATES.includes(next)||!UX_TRANSITIONS[current].includes(next))throw new Error('INVALID_UX_TRANSITION');return next;}
export function toPublicError(code,unsafeDetail=''){const safeCode=Object.hasOwn(PUBLIC_ERRORS,code)?code:'INTERNAL_FAILURE';return freeze({code:safeCode,message:PUBLIC_ERRORS[safeCode],retryWriteAutomatically:false,detailExposed:false,unsafeDetailRecorded:false,unsafeDetailLength:String(unsafeDetail).length});}
export function validateVisualPersistenceContract(){const findings=[];const commands=Object.entries(COMMAND_BOUNDARIES);if(commands.length!==7)findings.push('seven-command-coverage');for(const[name,command]of commands){if(!command.rpc.endsWith('_v1'))findings.push(`${name}:versioned-rpc`);if(!command.screen.startsWith('/'))findings.push(`${name}:screen`);if(!command.refresh.length||command.refresh.some(read=>!READ_MODELS[read]))findings.push(`${name}:read-model-refresh`);}for(const[name,read]of Object.entries(READ_MODELS))if(read.tenantFilter!=='server-resolved'||!read.empty)findings.push(`${name}:safe-read-model`);if(THREAT_MODEL.length<10)findings.push('threat-coverage');if(UX_TRANSITIONS.submitting.includes('submitting')||UX_TRANSITIONS.submitting.includes('succeeded'))findings.push('unsafe-submit-transition');return freeze({valid:findings.length===0,findings,version:CONTRACT_VERSION,commands:commands.length,readModels:Object.keys(READ_MODELS).length,threats:THREAT_MODEL.length,remoteAccessed:false,productionAccessed:false});}
