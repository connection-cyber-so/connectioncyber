// Rota protegida pelo middleware (src/middleware.ts) — só chega aqui quem
// tem sessão válida. Topbar, menu lateral e rodapé vêm do layout do route
// group (painel) — aqui só o conteúdo da home.
export const dynamic = 'force-dynamic';

import { visualDashboard, visualPersistenceMode } from '@/features/persistence/selected';

// M19-G2 — home redesenhada no padrão de apps/portal `/demo` (saudação +
// cards de KPI), mantendo os mesmos dados do M18-G11 (dashboard reconciliado
// server-side). .pf-grid-3 antes não existia em CSS — cards caíam sem grade.
//
// Sem nome na saudação de propósito: M18-G11 proíbe esta tela de importar
// Supabase/criar client direto (só o seletor fail-closed de persistência
// pode) — a identidade de quem está logado já aparece na topbar do layout,
// que é quem faz o auth.getUser().
export default async function DashboardPage() {
  const summary = await visualDashboard();

  return (
    <>
      <div className="pf-page-header">
        <div>
          <div className="pf-eyebrow">M18-G11 · painel reconciliado</div>
          <h1>Olá! Aqui está o resumo de hoje.</h1>
          <p>{visualPersistenceMode}.</p>
        </div>
      </div>
      <div className="pf-grid-3">
        <section className="pf-stat-card">
          <h2>Vendas</h2>
          <strong>{summary.salesCount}</strong>
          <p>R$ {summary.salesTotal.toFixed(2)}</p>
        </section>
        <section className="pf-stat-card">
          <h2>Estoque</h2>
          <strong>{summary.stockUnits} UN</strong>
          <p>{summary.products} produto(s)</p>
        </section>
        <section className="pf-stat-card">
          <h2>Financeiro</h2>
          <strong>R$ {summary.openReceivables.toFixed(2)}</strong>
          <p>em aberto</p>
        </section>
        <section className="pf-stat-card">
          <h2>Caixa</h2>
          <strong>{summary.cashStatus}</strong>
          <p>Vendas em dinheiro R$ {summary.cashSales.toFixed(2)}</p>
        </section>
        <section className="pf-stat-card">
          <h2>Clientes</h2>
          <strong>{summary.customers}</strong>
        </section>
        <section className="pf-stat-card">
          <h2>Reconciliação</h2>
          <strong>{summary.balanced ? 'Conciliado' : 'Divergente'}</strong>
          <p>Vendas = caixa + recebíveis</p>
        </section>
      </div>
    </>
  );
}
