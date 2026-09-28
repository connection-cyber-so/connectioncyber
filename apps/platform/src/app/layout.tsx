import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'ConnectionCyber — Painel Interno',
  description: 'Painel interno de gestão de tenants, módulos e clientes da ConnectionCyber.',
  robots: { index: false, follow: false },
};

// Script bloqueante e inofensivo: só lê a preferência de tema salva
// (localStorage 'cc-theme') e aplica a classe em <html> antes da primeira
// pintura, pra não piscar claro→escuro. Sem isso o dark mode só apareceria
// depois do React montar o ThemeToggle.
const THEME_INIT_SCRIPT = `(function(){try{var t=localStorage.getItem('cc-theme');if(t==='dark'||t==='light'){document.documentElement.classList.add(t);}}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
