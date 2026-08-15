import { createClient } from '@/lib/supabase/server';
import { LogoutButton } from '@/components/LogoutButton';

// Depende de sessão (cookies) a cada request — nunca deve ser pré-renderizada
// estaticamente no build, senão o build tenta gerar a página sem sessão nenhuma.
export const dynamic = 'force-dynamic';

// Rota protegida pelo middleware (src/middleware.ts) — só chega aqui quem
// tem sessão válida. Lista de tenants (Fase 2 do plano de ação) ainda não
// existe; o primeiro módulo de negócio real já está em /diagnostics.
export default async function DashboardPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <div className="pf-shell">
      <header className="pf-topbar">
        <div className="pf-brand">
          <span className="dot" />
          ConnectionCyberSO
        </div>
        <LogoutButton />
      </header>
      <main className="pf-main">
        <div className="pf-card" style={{ textAlign: 'center' }}>
          <div className="pf-eyebrow">Painel Interno</div>
          <h1 className="pf-title">Bem-vindo</h1>
          <p className="pf-muted">
            Sessão ativa como <strong>{user?.email}</strong>.
          </p>
          <p className="pf-muted" style={{ marginTop: 16 }}>
            A lista de tenants entra na próxima etapa do roteiro.
          </p>
          <a href="/diagnostics" className="pf-button" style={{ display: 'inline-block', marginTop: 20, textDecoration: 'none' }}>
            Abrir Diagnóstico Digital
          </a>
        </div>
      </main>
    </div>
  );
}
