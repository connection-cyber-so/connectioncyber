const modules = [
  { name: 'Cadastros', description: 'Pessoas, produtos, serviços e unidades.', gate: 'M05' },
  { name: 'Estoque', description: 'Depósitos, movimentos, inventário e compras.', gate: 'M06' },
  { name: 'Vendas', description: 'Orçamentos, pedidos, PDV e recebimentos.', gate: 'M07' },
  { name: 'Financeiro', description: 'Contas, caixa, conciliação e cobrança.', gate: 'M08' },
];

export const dynamic = 'force-dynamic';

export default function DashboardPage() {
  return (
    <>
      <div className="content-heading">
        <div>
          <span className="eyebrow">Visão geral</span>
          <h1>Gestão da empresa</h1>
          <p className="lead">
            O shell M03 está em modo somente leitura. Cada módulo será liberado após seu portão de validação.
          </p>
        </div>
        <span className="status-chip">Contexto validado</span>
      </div>

      <section className="module-grid" aria-label="Próximos módulos do ERP">
        {modules.map((module) => (
          <article className="module-card" key={module.name}>
            <div className="module-icon" aria-hidden="true">{module.name.slice(0, 1)}</div>
            <div>
              <span className="module-gate">Previsto para {module.gate}</span>
              <h2>{module.name}</h2>
              <p>{module.description}</p>
            </div>
          </article>
        ))}
      </section>

      <section className="security-card">
        <div>
          <span className="eyebrow">Segurança M03</span>
          <h2>Quatro confirmações antes de mostrar dados</h2>
        </div>
        <ol>
          <li>Hostname empresarial ativo</li>
          <li>Tenant ativo</li>
          <li>Sessão validada no servidor</li>
          <li>Membership ativa e compatível</li>
        </ol>
      </section>
    </>
  );
}
