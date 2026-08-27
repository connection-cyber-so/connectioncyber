export type ServiceOrder={id:string;code:string;status:string;priority:string;complaint:string|null;grand_total:number;opened_at:string;erp_assets:{name:string;code:string}|null;erp_parties:{legal_name:string}|null};
export type Appointment={id:string;code:string;status:string;starts_at:string;ends_at:string;erp_assets:{name:string}|null;erp_parties:{legal_name:string}|null};
export type Asset={id:string;code:string;name:string;kind:string;brand:string|null;model:string|null};
