'use client';

import type { ReactNode } from 'react';
import { usePathname } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import './crm-shell.css';

// Menu lateral do porte CRM (visual copiado da Nuvem de Papel).
// Só links de rotas que já existem no portal; os demais entram ao serem portados.
const LINKS = [
  { href: '/crm/clientes', label: 'Clientes' },
  { href: '/crm/produtos', label: 'Produtos' },
  { href: '/crm/estoque', label: 'Estoque' },
];

export function CrmShell({ children }: { children: ReactNode }) {
  const pathname = usePathname() ?? '';

  async function sair() {
    await createClient().auth.signOut();
    window.location.href = '/login';
  }

  return (
    <div className="admin-shell">
      <aside className="admin-side">
        <div className="admin-side-inner">
          <div className="admin-brand">
            <span>
              <span className="admin-brand-name">Nuvem de Papel</span>
              <span className="admin-brand-sub">Painel</span>
            </span>
          </div>
          <nav className="admin-nav" aria-label="Navegação do painel">
            <div className="admin-nav-item">
              <a href="/crm" className="admin-link">Painel CRM</a>
            </div>
            <div className="admin-group-label">Cadastros</div>
            {LINKS.map((l) => (
              <div className="admin-nav-item" key={l.href}>
                <a href={l.href} className={pathname.startsWith(l.href) ? 'admin-link admin-link--on' : 'admin-link'} aria-current={pathname.startsWith(l.href) ? 'page' : undefined}>
                  {l.label}
                </a>
              </div>
            ))}
          </nav>
          <div className="admin-foot">
            <button type="button" className="admin-sair" onClick={sair}>Sair</button>
          </div>
        </div>
      </aside>
      <div className="admin-main">{children}</div>
    </div>
  );
}
