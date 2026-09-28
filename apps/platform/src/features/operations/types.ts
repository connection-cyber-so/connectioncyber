export type PriceList={id:string;code:string;name:string;currency_code:string;channel:string;active:boolean};
export type StockLocation={id:string;code:string;name:string;kind:string;allows_negative:boolean;erp_establishments:{name:string}|null};
export type PurchaseOrder={id:string;code:string;status:string;grand_total:number;currency_code:string;erp_parties:{legal_name:string}|null};
