'use client';

import type { ReactNode } from 'react';
import { usePathname } from 'next/navigation';
import './crm-shell.css';

// Menu lateral do porte CRM (visual copiado da Nuvem de Papel, imagem 7 do protótipo).
// `live: true` = rota real no portal. Os demais levam à página "Em construção" (sem 404).
type MenuItem = { label: string; href: string; live?: boolean };
type MenuGroup = { title?: string; items: MenuItem[] };

const em = (modulo: string) => `/crm/em-construcao?modulo=${encodeURIComponent(modulo)}`;

const GROUPS: MenuGroup[] = [
  { items: [{ label: 'Painel CRM', href: '/crm', live: true }] },
  {
    title: 'Vendas',
    items: [
      { label: 'PDV', href: em('PDV') },
      { label: 'Vendas Detalhada', href: em('Vendas Detalhada') },
    ],
  },
  {
    items: [
      { label: 'Financeiro', href: em('Financeiro') },
      { label: 'Logística', href: em('Logística') },
      { label: 'Marketing', href: em('Marketing') },
      { label: 'Carta com IA', href: em('Carta com IA') },
    ],
  },
  {
    title: 'Cadastros',
    items: [
      { label: 'Clientes', href: '/crm/clientes', live: true },
      { label: 'Produtos', href: em('Produtos') },
      { label: 'Estoque', href: em('Estoque') },
    ],
  },
  {
    items: [
      { label: 'E-mail', href: em('E-mail') },
      { label: 'Catálogo', href: em('Catálogo') },
      { label: 'Publicações', href: em('Publicações') },
      { label: 'Configurações', href: em('Configurações') },
    ],
  },
];

function isActive(pathname: string, href: string) {
  if (href === '/crm') return pathname === '/crm';
  return pathname === href || pathname.startsWith(`${href}/`);
}

export function CrmShell({ children }: { children: ReactNode }) {
  const pathname = usePathname() ?? '';

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
            {GROUPS.map((group, gi) => (
              <div key={gi}>
                {group.title ? <div className="admin-group-label">{group.title}</div> : null}
                {group.items.map((item) => {
                  const on = Boolean(item.live) && isActive(pathname, item.href);
                  return (
                    <div className="admin-nav-item" key={item.label}>
                      <a href={item.href} className={on ? 'admin-link admin-link--on' : 'admin-link'} aria-current={on ? 'page' : undefined}>
                        {item.label}
                      </a>
                    </div>
                  );
                })}
              </div>
            ))}
          </nav>
          <div className="admin-foot">
            <form method="post" action="/auth/logout">
              <button type="submit" className="admin-sair">Sair</button>
            </form>
          </div>
        </div>
      </aside>
      <div className="admin-main">{children}</div>
    </div>
  );
}
