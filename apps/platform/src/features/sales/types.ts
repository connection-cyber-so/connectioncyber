export type Quote={id:string;code:string;status:string;grand_total:number;currency_code:string;valid_until:string|null};
export type Sale={id:string;code:string;status:string;grand_total:number;currency_code:string;completed_at:string|null};
export type CashSession={id:string;status:string;opened_at:string;opening_amount:number;erp_cash_registers:{code:string;name:string}|null};
export type PaymentMethod={id:string;code:string;name:string;kind:string};
