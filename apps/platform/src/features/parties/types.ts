export type PartyKind = 'person' | 'organization';
export type PartyRole = 'customer' | 'supplier' | 'employee' | 'buyer' | 'sales_rep' | 'technician' | 'carrier' | 'other';
export interface Party { id:string; tenant_id:string; kind:PartyKind; legal_name:string; trade_name:string|null; tax_id:string|null; active:boolean; created_at:string; erp_party_roles:{role:PartyRole;active:boolean}[]; }
