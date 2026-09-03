import type { ReactNode } from 'react';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { Brand } from '@/components/Brand';
import { ThemeToggle } from '@/components/ThemeToggle';
import { loadPortalAccess } from '@/lib/portal-context';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function PortalLayout({ children }: { children: ReactNode }) {
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind === 'login') redirect('/login?redirect=%2Fdashboard');
  if (access.kind === 'forbidden') redirect('/acesso-negado');
  if (access.kind === 'no-membership') redirect('/sem-empresa');
  if (access.kind === 'select-membership') redirect('/selecionar-empresa');
  if (access.kind === 'configuration-missing' || access.kind === 'service-unavailable') {
    redirect('/');
  }

  return (
    <div className="portal-shell">
      <header className="portal-topbar">
        <Brand />
        <div className="session-summary">
          <span>Empresa ativa</span>
          <strong>{access.membership.tenantName}</strong>
        </div>
        <div className="topbar-actions">
          <ThemeToggle />
          {access.host.kind === 'central' ? (
            <form method="post" action="/auth/clear-membership">
              <button className="button ghost compact" type="submit">Trocar empresa</button>
            </form>
          ) : null}
          <form method="post" action="/auth/logout">
            <button className="button ghost compact" type="submit">Sair</button>
          </form>
        </div>
      </header>

      <div className="portal-body">
        <aside className="portal-sidebar">
          <div className="tenant-badge">
            <span>Contexto protegido</span>
            <strong>{access.membership.tenantSlug}</strong>
          </div>
          <nav aria-label="Módulos do portal">
            <Link className="nav-item active" href="/dashboard">Início</Link>
            <span className="nav-item pending">Cadastros <small>M05</small></span>
            <span className="nav-item pending">Estoque <small>M06</small></span>
            <span className="nav-item pending">Vendas <small>M07</small></span>
            <span className="nav-item pending">Financeiro <small>M08</small></span>
            <span className="nav-item pending">Suporte <small>M12</small></span>
          </nav>
        </aside>
        <main className="portal-content">{children}</main>
      </div>

      <footer className="portal-footer">
        <span>ConnectionCyber Assessoria e Treinamento</span>
        <span>Tecnologia que traz conhecimento e gestão</span>
      </footer>
    </div>
  );
}
