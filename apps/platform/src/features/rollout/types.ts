export type RolloutStage = 'laboratory' | 'canary' | 'cohort' | 'complete';
export type TenantRolloutStatus = 'pending' | 'active' | 'promoted' | 'rolled_back';
export type RolloutMetrics = { observations: number; errorRate: number; latencyP95Ms: number; crossTenantViolations: number; rollbackReady: boolean };
export type RolloutTenant = { id: string; name: string; profile: 'MEI' | 'ME' | 'LTDA'; stage: RolloutStage; status: TenantRolloutStatus; metrics: RolloutMetrics; release: string; previousRelease: string };
export type PromotionDecision = { allowed: boolean; reasons: string[]; nextStage: RolloutStage };
