export type ItemKind='product'|'service'|'part'|'ingredient'|'prepared'|'kit'|'supply'|'fee'|'voucher';
export interface Unit{id:string;code:string;name:string;dimension:string;decimal_scale:number}
export interface CatalogItem{id:string;tenant_id:string;kind:ItemKind;code:string;name:string;description:string|null;track_inventory:boolean;allows_fraction:boolean;status:string;erp_units:{code:string;name:string}|null}
// M20-G1/G3 — aba Fiscal do item, ver PARECER-TECNICO-M20-G0.
export type TaxCodeKind='CST'|'CSOSN';
export interface ItemFiscalData{item_id:string;ncm:string;cest:string|null;origin:number;tax_code_kind:TaxCodeKind;tax_code:string;icms_rate:number;icms_base_percent:number;ipi_rate:number;cst_pis:string|null;cst_cofins:string|null;fcp_rate:number;gross_weight:number|null;net_weight:number|null;anp_code:string|null}
// M20-G1/G3 — aba Comercial do item.
export interface ItemCommercialData{item_id:string;cost_price:number;margin_percent:number;suggested_sale_price:number|null;min_stock_quantity:number;reorder_point:number|null;reorder_quantity:number|null}
// M20-G2/G3 — vertical de negócio + template de atributo exigido, usados na aba Atributos.
export interface BusinessVertical{code:string;name:string;description:string|null;segment_profile_key:string|null;active:boolean}
export interface VerticalAttributeRequirement{vertical_code:string;attribute_code:string;attribute_name:string;data_type:'option'|'text'|'number'|'boolean';required:boolean;sort_order:number}
