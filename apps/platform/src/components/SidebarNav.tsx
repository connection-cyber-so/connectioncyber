'use client';

import { usePathname } from 'next/navigation';

// Agrupado por assunto (2026-09-03): a lista era 19 links soltos, sem
// hierarquia — visão de equipe, cadastro/catálogo, operação, financeiro,
// segmentos verticais, atendimento e os módulos de IA/marketing ficavam
// todos misturados na mesma ordem. Reorganizado em seções para navegação
// mais direta; a URL de cada rota não mudou, só o agrupamento visual.
const GROUPS = [
  {
    label: 'Visão geral',
    items: [
      { href: '/tenants', label: 'Tenants' },
      { href: '/identidades', label: 'Identidades e acessos' },
      { href: '/capacidades', label: 'Capacidades e planos' },
      { href: '/implantacao', label: 'Implantação em ondas' },
    ],
  },
  {
    label: 'Cadastros e catálogo',
    items: [
      { href: '/cadastros', label: 'Cadastros ERP' },
      { href: '/catalogo', label: 'Catálogo universal' },
    ],
  },
  {
    label: 'Operação',
    items: [
      { href: '/operacoes', label: 'Preços, estoque e compras' },
      { href: '/vendas', label: 'Orçamentos e vendas' },
      { href: '/pdv', label: 'PDV e caixa' },
    ],
  },
  {
    label: 'Financeiro',
    items: [
      { href: '/financeiro', label: 'Financeiro' },
      { href: '/bancos', label: 'Bancos e conciliação' },
    ],
  },
  {
    label: 'Segmentos',
    items: [
      { href: '/servicos', label: 'Serviços e oficinas' },
      { href: '/alimentacao', label: 'Restaurantes e lanchonetes' },
    ],
  },
  {
    label: 'Atendimento',
    items: [{ href: '/atendimento', label: 'Atendimento e acesso remoto' }],
  },
  {
    label: 'Marketing e conteúdo (IA)',
    items: [
      { href: '/diagnostics', label: 'Diagnóstico Digital' },
      { href: '/products', label: 'Produtos' },
      { href: '/offers', label: 'Ofertas' },
      { href: '/video-scripts', label: 'Roteiros de Vídeo' },
      { href: '/landing-pages', label: 'Landing Pages' },
    ],
  },
];

export function SidebarNav() {
  const pathname = usePathname();

  return (
    <nav className="pf-sidebar">
      {GROUPS.map((group) => (
        <div key={group.label} className="pf-sidebar-group">
          <div className="pf-sidebar-group-label">{group.label}</div>
          {group.items.map((item) => {
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
        </div>
      ))}
    </nav>
  );
}
