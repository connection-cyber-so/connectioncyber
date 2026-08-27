export type DiningTable={id:string;code:string;name:string;capacity:number;status:string;erp_dining_areas:{name:string}|null};
export type FoodTab={id:string;code:string;channel:string;status:string;guest_count:number;grand_total:number;opened_at:string};
export type KitchenTicket={id:string;code:string;status:string;priority:number;queued_at:string;erp_kitchen_stations:{name:string}|null};
