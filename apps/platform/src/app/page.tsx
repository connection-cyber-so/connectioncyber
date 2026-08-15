import { createClient } from '@/lib/supabase/server';
import { LogoutButton } from '@/components/LogoutButton';

// Depende de sessão (cookies) a cada request — nunca deve ser pré-renderizada
// estaticamente no build, senão o build tenta gerar a página sem sessão nenhuma.
export const dynamic = 'force-dynamic';

// Rota protegida pelo middleware (src/middleware.ts) — só chega aqui quem
// tem sessão válida. Ainda sem conteúdo de negócio: a lista de tenants é a
// Fase 2 do plano de ação, não esta (Fase 1 = esqueleto + login).
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
            A lista de tenants e os módulos de gestão entram na próxima etapa do roteiro.
          </p>
        </div>
      </main>
    </div>
  );
}
