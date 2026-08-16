/**
 * Mapa central de rotas do site — evita strings soltas nos componentes.
 */
export const routes = {
  home: '/',
  sobre: '/sobre',
  servicos: '/servicos',
  cursos: '/cursos',
  produtos: '/produtos',
  sistema: '/sistema',
  clientes: '/clientes',
  membros: '/membros',
  login: '/login',
  contato: '/contato',
  checkout: '/checkout',
  pagamentoSucesso: '/pagamento/sucesso',
  pagamentoErro: '/pagamento/erro',
} as const;

export type RouteKey = keyof typeof routes;

/** Links de navegação principal exibidos no Header. */
export const mainNav: { key: RouteKey; labelKey: string }[] = [
  { key: 'home', labelKey: 'nav.home' },
  { key: 'sobre', labelKey: 'nav.about' },
  { key: 'servicos', labelKey: 'nav.services' },
  { key: 'cursos', labelKey: 'nav.courses' },
  { key: 'produtos', labelKey: 'nav.products' },
  { key: 'clientes', labelKey: 'nav.clients' },
  { key: 'sistema', labelKey: 'nav.system' },
  { key: 'contato', labelKey: 'nav.contact' },
];

/** Redes sociais exibidas nos botões flutuantes e no rodapé. */
export const socialLinks = {
  whatsapp: 'https://wa.me/5511967426682',
  instagram: 'https://instagram.com/connectioncyber',
  facebook: 'https://facebook.com/connectioncyber',
  linkedin: 'https://linkedin.com/company/connectioncyber',
  youtube: 'https://youtube.com/@connectioncyber',
  tiktok: 'https://tiktok.com/@connectioncyber',
};
