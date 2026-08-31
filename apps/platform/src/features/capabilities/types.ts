export type LegalProfile='MEI'|'ME'|'LTDA';
export type CapabilityStatus='enabled'|'disabled'|'blocked';
export type CapabilityEffect='allow'|'deny';
export type SyntheticTenant={id:string;name:string;profile:LegalProfile};
export type CapabilityDefinition={key:string;name:string;group:string;critical?:boolean};
export type CapabilityException={id:string;tenantId:string;capabilityKey:string;effect:CapabilityEffect;expiresAt:string;active:boolean};
