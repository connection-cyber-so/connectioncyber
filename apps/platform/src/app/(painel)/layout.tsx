import { createClient } from '@/lib/supabase/server';
import { isPlatformStaff } from '@/lib/staff';
import { LogoutButton } from '@/components/LogoutButton';
import { SidebarNav } from '@/components/SidebarNav';

// Layout compartilhado por todo o painel autenticado (dashboard + módulos).
// /login fica fora deste route group — não leva topbar/menu/rodapé.
//
// Gate de equipe (2026-08-15): a RLS multi-tenant sempre impediu ver dado de
// outro tenant, mas nada impedia o LOGIN em si — qualquer conta autenticada
// (aluno, cliente) conseguia abrir o painel inteiro. is_platform_staff()
// fecha essa lacuna: quem não é admin/suporte vê a tela de acesso restrito
// abaixo, nunca o dashboard/menu/módulos.
export default async function PainelLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const staff = await isPlatformStaff();

  if (!staff) {
    return (
      <div className="pf-painel">
        <header className="pf-topbar">
          <a href="/" className="pf-brand">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/logo.png" alt="ConnectionCyber" className="pf-brand-logo" />
            <span className="pf-wordmark">
              <span className="pf-wordmark-connection">Connection</span>
              <span className="pf-wordmark-cyber">Cyber</span>
            </span>
          </a>
          <div className="pf-topbar-right">
            <LogoutButton />
          </div>
        </header>
        <main className="pf-content" style={{ display: 'flex', justifyContent: 'center', padding: '64px 24px' }}>
          <div className="pf-content-card" style={{ maxWidth: 440, textAlign: 'center' }}>
            <div className="pf-eyebrow">Painel interno</div>
            <h1 className="pf-title" style={{ marginBottom: 8 }}>
              Acesso restrito
            </h1>
            <p className="pf-muted">
              Este painel é de uso exclusivo da equipe ConnectionCyber. A conta{' '}
              <strong>{user?.email}</strong> não tem esse papel.
            </p>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="pf-painel">
      <header className="pf-topbar">
        <a href="/" className="pf-brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/logo.png" alt="ConnectionCyber" className="pf-brand-logo" />
          <span className="pf-wordmark">
            <span className="pf-wordmark-connection">Connection</span>
            <span className="pf-wordmark-cyber">Cyber</span>
          </span>
        </a>

        <div className="pf-topbar-right">
          <div className="pf-welcome">
            <div className="pf-welcome-eyebrow">Painel interno · Bem-vindo</div>
            <div className="pf-welcome-session">
              Sessão ativa como <strong>{user?.email}</strong>
            </div>
          </div>
          <LogoutButton />
        </div>
      </header>

      <div className="pf-painel-body">
        <SidebarNav />
        <main className="pf-content">{children}</main>
      </div>

      <footer className="pf-footer">
        <span>© {new Date().getFullYear()} ConnectionCyber — Todos os direitos reservados.</span>
        <span className="pf-footer-brand">
          <span className="pf-wordmark-connection">Connection</span>
          <span className="pf-wordmark-cyber">Cyber</span>
        </span>
      </footer>
    </div>
  );
}
