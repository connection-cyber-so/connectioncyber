import type { PromotionDecision, RolloutMetrics, RolloutStage, RolloutTenant } from './types';

export const rolloutStages: RolloutStage[] = ['laboratory', 'canary', 'cohort', 'complete'];
export const stageLabels: Record<RolloutStage, string> = { laboratory: 'Laboratório', canary: 'Canário', cohort: 'Coorte', complete: 'Concluída' };

export function evaluatePromotion(stage: RolloutStage, metrics: RolloutMetrics): PromotionDecision {
  const reasons: string[] = [];
  if (metrics.observations < 100) reasons.push('Mínimo de 100 observações não atingido');
  if (metrics.errorRate > 1) reasons.push('Taxa de erro acima de 1%');
  if (metrics.latencyP95Ms > 500) reasons.push('Latência p95 acima de 500 ms');
  if (metrics.crossTenantViolations !== 0) reasons.push('Violação de isolamento detectada');
  if (!metrics.rollbackReady) reasons.push('Rollback não está pronto');
  const index = rolloutStages.indexOf(stage);
  return { allowed: reasons.length === 0 && stage !== 'complete', reasons: stage === 'complete' ? ['Tenant já concluiu todas as ondas'] : reasons, nextStage: rolloutStages[Math.min(index + 1, rolloutStages.length - 1)] };
}

export function promoteTenant(tenant: RolloutTenant): RolloutTenant {
  const decision = evaluatePromotion(tenant.stage, tenant.metrics);
  return decision.allowed ? { ...tenant, stage: decision.nextStage, status: decision.nextStage === 'complete' ? 'promoted' : 'active' } : tenant;
}

export function rollbackTenant(tenant: RolloutTenant): RolloutTenant {
  if (!tenant.metrics.rollbackReady || tenant.status === 'rolled_back') return tenant;
  return { ...tenant, release: tenant.previousRelease, status: 'rolled_back' };
}
