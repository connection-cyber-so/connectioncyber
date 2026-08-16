import { createClient } from '@/lib/supabase/server';
import { LogoutButton } from '@/components/LogoutButton';
import { SidebarNav } from '@/components/SidebarNav';

// Layout compartilhado por todo o painel autenticado (dashboard + módulos).
// /login fica fora deste route group — não leva topbar/menu/rodapé.
export default async function PainelLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

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
