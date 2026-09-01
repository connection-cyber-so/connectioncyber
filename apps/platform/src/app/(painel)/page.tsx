// Rota protegida pelo middleware (src/middleware.ts) — só chega aqui quem
// tem sessão válida. Topbar, menu lateral e rodapé vêm do layout do route
// group (painel) — aqui só o conteúdo da home.
export const dynamic = 'force-dynamic';

import{visualDashboard,visualPersistenceMode}from'@/features/persistence/selected';
export default async function DashboardPage() {const summary=await visualDashboard();
  return (
    <><div className="pf-page-header"><div><div className="pf-eyebrow">M18-G11 · painel reconciliado</div><h1>Visão operacional</h1><p>{visualPersistenceMode}.</p></div></div><div className="pf-grid-3"><section className="pf-content-card"><h2>Vendas</h2><strong>{summary.salesCount}</strong><p>R$ {summary.salesTotal.toFixed(2)}</p></section><section className="pf-content-card"><h2>Estoque</h2><strong>{summary.stockUnits} UN</strong><p>{summary.products} produto(s)</p></section><section className="pf-content-card"><h2>Financeiro</h2><strong>R$ {summary.openReceivables.toFixed(2)}</strong><p>em aberto</p></section><section className="pf-content-card"><h2>Caixa</h2><strong>{summary.cashStatus}</strong><p>Vendas em dinheiro R$ {summary.cashSales.toFixed(2)}</p></section><section className="pf-content-card"><h2>Clientes</h2><strong>{summary.customers}</strong></section><section className="pf-content-card"><h2>Reconciliação</h2><strong>{summary.balanced?'Conciliado':'Divergente'}</strong><p>Vendas = caixa + recebíveis</p></section></div></>
  );
}
