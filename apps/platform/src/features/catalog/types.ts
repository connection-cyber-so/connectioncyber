export type ItemKind='product'|'service'|'part'|'ingredient'|'prepared'|'kit'|'supply'|'fee'|'voucher';
export interface Unit{id:string;code:string;name:string;dimension:string;decimal_scale:number}
export interface CatalogItem{id:string;tenant_id:string;kind:ItemKind;code:string;name:string;description:string|null;track_inventory:boolean;allows_fraction:boolean;status:string;erp_units:{code:string;name:string}|null}
