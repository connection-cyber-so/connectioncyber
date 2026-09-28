'use client';

import { useMemo, useState } from 'react';
import { evaluatePromotion, promoteTenant, rollbackTenant, rolloutStages, stageLabels } from '../engine';
import { initialSyntheticRollout } from '../presentation';

export function RolloutSimulator() {
  const [tenants, setTenants] = useState(initialSyntheticRollout);
  const [selectedId, setSelectedId] = useState(initialSyntheticRollout[0].id);
  const tenant = tenants.find(item => item.id === selectedId) ?? tenants[0];
  const decision = useMemo(() => evaluatePromotion(tenant.stage, tenant.metrics), [tenant]);
  const updateMetrics = (healthy: boolean) => setTenants(current => current.map(item => item.id === tenant.id ? { ...item, metrics: healthy ? { observations: 250, errorRate: 0.3, latencyP95Ms: 280, crossTenantViolations: 0, rollbackReady: true } : { ...item.metrics, errorRate: 3.5, crossTenantViolations: 1 } } : item));
  const promote = () => setTenants(current => current.map(item => item.id === tenant.id ? promoteTenant(item) : item));
  const rollback = () => setTenants(current => current.map(item => item.id === tenant.id ? rollbackTenant(item) : item));
  const reset = () => { setTenants(initialSyntheticRollout); setSelectedId(initialSyntheticRollout[0].id); };

  return <>
    <div className="pf-page-header"><div><div className="pf-eyebrow">M16-G8 · simulação local</div><h1>Implantação em ondas</h1><p>Promova ou reverta uma empresa por vez com critérios verificáveis.</p></div><span className="pf-capability-mode">Sem rede</span></div>
    <div className="pf-capability-warning" role="status"><strong>Ambiente totalmente sintético.</strong> Nenhum botão publica versão, altera tenant real ou chama serviço remoto.</div>
    <section className="pf-rollout-flow" aria-label="Ondas de implantação">{rolloutStages.map((stage, index) => <article key={stage} className={tenant.stage === stage ? 'active' : ''}><small>Onda {index + 1}</small><strong>{stageLabels[stage]}</strong></article>)}</section>
    <section className="pf-capability-toolbar"><label>Empresa sintética<select value={selectedId} onChange={event => setSelectedId(event.target.value)}>{tenants.map(item => <option key={item.id} value={item.id}>{item.name} · {item.profile}</option>)}</select></label><div><span>Release candidata</span><strong>{tenant.release}</strong></div><div><span>Estado</span><strong>{tenant.status}</strong></div></section>
    <div className="pf-rollout-layout"><section className="pf-content-card"><div className="pf-card-head"><div><div className="pf-eyebrow">Go / no-go determinístico</div><h2>{decision.allowed ? 'Promoção autorizada' : 'Promoção bloqueada'}</h2></div><span className={`pf-capability-status ${decision.allowed ? 'enabled' : 'blocked'}`}>{decision.allowed ? 'GO' : 'NO-GO'}</span></div>
      <div className="pf-rollout-criteria"><article><strong>{tenant.metrics.observations}</strong><span>observações ≥ 100</span></article><article><strong>{tenant.metrics.errorRate}%</strong><span>erro ≤ 1%</span></article><article><strong>{tenant.metrics.latencyP95Ms} ms</strong><span>p95 ≤ 500 ms</span></article><article><strong>{tenant.metrics.crossTenantViolations}</strong><span>violações = 0</span></article><article><strong>{tenant.metrics.rollbackReady ? 'Pronto' : 'Bloqueado'}</strong><span>rollback preparado</span></article></div>
      {decision.reasons.length > 0 && <ul className="pf-rollout-reasons">{decision.reasons.map(reason => <li key={reason}>{reason}</li>)}</ul>}
      <div className="pf-inline-actions"><button className="pf-button" type="button" disabled={!decision.allowed || tenant.status === 'rolled_back'} onClick={promote}>Promover para {stageLabels[decision.nextStage]}</button><button className="pf-button pf-button-secondary" type="button" onClick={() => updateMetrics(true)}>Simular janela saudável</button><button className="pf-link-btn" type="button" onClick={() => updateMetrics(false)}>Simular incidente</button></div>
    </section><aside className="pf-content-card pf-rollout-rollback"><div className="pf-eyebrow">Rollback por tenant</div><h2>Reversão isolada</h2><p>Somente <strong>{tenant.name}</strong> retorna à versão anterior. As demais empresas preservam versão e onda.</p><dl><div><dt>Atual</dt><dd>{tenant.release}</dd></div><div><dt>Anterior</dt><dd>{tenant.previousRelease}</dd></div></dl><button className="pf-button" type="button" disabled={!tenant.metrics.rollbackReady || tenant.status === 'rolled_back'} onClick={rollback}>Executar rollback sintético</button><button className="pf-link-btn" type="button" onClick={reset}>Restaurar cenário inicial</button></aside></div>
  </>;
}
