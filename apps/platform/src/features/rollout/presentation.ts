import type { RolloutTenant } from './types';

export const initialSyntheticRollout: RolloutTenant[] = [
  { id: 'SYNTHETIC-ROLLOUT-MEI', name: 'SYNTHETIC Studio Criativo', profile: 'MEI', stage: 'laboratory', status: 'active', release: '2026.08.31-rc1', previousRelease: '2026.08.30', metrics: { observations: 140, errorRate: 0.2, latencyP95Ms: 240, crossTenantViolations: 0, rollbackReady: true } },
  { id: 'SYNTHETIC-ROLLOUT-ME', name: 'SYNTHETIC Moda & Cia', profile: 'ME', stage: 'canary', status: 'active', release: '2026.08.31-rc1', previousRelease: '2026.08.30', metrics: { observations: 260, errorRate: 1.8, latencyP95Ms: 420, crossTenantViolations: 0, rollbackReady: true } },
  { id: 'SYNTHETIC-ROLLOUT-LTDA', name: 'SYNTHETIC Grupo Comercial', profile: 'LTDA', stage: 'cohort', status: 'active', release: '2026.08.31-rc1', previousRelease: '2026.08.30', metrics: { observations: 480, errorRate: 0.4, latencyP95Ms: 310, crossTenantViolations: 0, rollbackReady: true } },
];
