export type PartyKind = 'person' | 'organization';
export type PartyRole = 'customer' | 'supplier' | 'employee' | 'buyer' | 'sales_rep' | 'technician' | 'carrier' | 'other';
export interface Party { id:string; tenant_id:string; kind:PartyKind; legal_name:string; trade_name:string|null; tax_id:string|null; active:boolean; created_at:string; erp_party_roles:{role:PartyRole;active:boolean}[]; }
// M20-G3 — abas Documentos/Contatos/Endereços do cadastro de pessoa.
export type PartyDocumentType = 'cpf'|'cnpj'|'rg'|'passport'|'other';
export interface PartyDocument { id:string; party_id:string; type:PartyDocumentType; number:string; issuer:string|null; issued_at:string|null; expires_at:string|null; }
export type PartyContactType = 'email'|'phone'|'mobile'|'whatsapp'|'website'|'other';
export interface PartyContact { id:string; party_id:string; type:PartyContactType; value:string; label:string|null; is_primary:boolean; }
export type PartyAddressType = 'main'|'billing'|'shipping'|'service'|'other';
export interface PartyAddress { id:string; party_id:string; type:PartyAddressType; postal_code:string|null; street:string; number:string|null; complement:string|null; district:string|null; city:string; state_code:string|null; country_code:string; is_primary:boolean; }
