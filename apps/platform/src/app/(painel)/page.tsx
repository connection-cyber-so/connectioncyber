// Rota protegida pelo middleware (src/middleware.ts) — só chega aqui quem
// tem sessão válida. Topbar, menu lateral e rodapé vêm do layout do route
// group (painel) — aqui só o conteúdo da home.
export const dynamic = 'force-dynamic';

export default function DashboardPage() {
  return (
    <div className="pf-content-card">
      <div className="pf-eyebrow">Painel interno</div>
      <h1 className="pf-title" style={{ marginBottom: 8 }}>
        Bem-vindo
      </h1>
      <p className="pf-muted">Selecione um módulo no menu à esquerda para começar.</p>
    </div>
  );
}
