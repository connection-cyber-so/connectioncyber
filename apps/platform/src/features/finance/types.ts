export type FinancialEntry={id:string;code:string;direction:'receivable'|'payable';status:string;principal_amount:number;currency_code:string;due_date:string};
export type FinancialAccount={id:string;code:string;name:string;kind:string;currency_code:string};
export type BankAccount={id:string;bank_code:string;branch_code:string|null;account_masked:string;account_type:string;erp_financial_accounts:{name:string}|null};
export type BankReconciliation={id:string;period_from:string;period_to:string;status:string;opening_balance:number;closing_balance:number};
