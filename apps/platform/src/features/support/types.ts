export type SupportTicket={id:string;code:string;subject:string;priority:string;status:string;source:string;created_at:string;erp_parties:{legal_name:string}|null;erp_assets:{name:string}|null};
export type ManagedDevice={id:string;code:string;name:string;status:string;agent_version:string|null;last_seen_at:string|null;erp_assets:{name:string}|null};
export type RemoteSession={id:string;status:string;started_at:string|null;ended_at:string|null;erp_support_tickets:{code:string}|null;erp_managed_devices:{name:string}|null};
