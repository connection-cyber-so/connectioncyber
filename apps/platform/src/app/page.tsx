import { createClient } from '@/lib/supabase/server';
import { LogoutButton } from '@/components/LogoutButton';

// Depende de sessão (cookies) a cada request — nunca deve ser pré-renderizada
// estaticamente no build, senão o build tenta gerar a página sem sessão nenhuma.
export const dynamic = 'force-dynamic';

// Rota protegida pelo middleware (src/middleware.ts) — só chega aqui quem
// tem sessão válida.
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
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 20 }}>
            <a href="/tenants" className="pf-button" style={{ textDecoration: 'none' }}>
              Tenants
            </a>
            <a href="/diagnostics" className="pf-button pf-button-secondary" style={{ textDecoration: 'none' }}>
              Diagnóstico Digital
            </a>
            <a href="/products" className="pf-button pf-button-secondary" style={{ textDecoration: 'none' }}>
              Produtos
            </a>
            <a href="/offers" className="pf-button pf-button-secondary" style={{ textDecoration: 'none' }}>
              Ofertas
            </a>
            <a href="/video-scripts" className="pf-button pf-button-secondary" style={{ textDecoration: 'none' }}>
              Roteiros de Vídeo
            </a>
            <a href="/landing-pages" className="pf-button pf-button-secondary" style={{ textDecoration: 'none' }}>
              Landing Pages
            </a>
          </div>
        </div>
      </main>
    </div>
  );
}
