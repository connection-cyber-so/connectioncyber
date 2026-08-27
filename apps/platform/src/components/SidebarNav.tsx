'use client';

import { usePathname } from 'next/navigation';

const ITEMS = [
  { href: '/tenants', label: 'Tenants' },
  { href: '/identidades', label: 'Identidades e acessos' },
  { href: '/cadastros', label: 'Cadastros ERP' },
  { href: '/catalogo', label: 'Catálogo universal' },
  { href: '/operacoes', label: 'Preços, estoque e compras' },
  { href: '/diagnostics', label: 'Diagnóstico Digital' },
  { href: '/products', label: 'Produtos' },
  { href: '/offers', label: 'Ofertas' },
  { href: '/video-scripts', label: 'Roteiros de Vídeo' },
  { href: '/landing-pages', label: 'Landing Pages' },
];

export function SidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="pf-sidebar">
      {ITEMS.map((item) => {
        const active = pathname === item.href;
        return (
          <a
            key={item.href}
            href={item.href}
            className={`pf-sidebar-link${active ? ' active' : ''}`}
            aria-current={active ? 'page' : undefined}
          >
            {item.label}
          </a>
        );
      })}
    </nav>
  );
}
