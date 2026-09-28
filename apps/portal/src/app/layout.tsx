import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import './globals.css';

export const metadata: Metadata = {
  title: 'Portal empresarial | ConnectionCyber',
  description: 'Gestão empresarial segura, multiempresa e multissegmento.',
  robots: { index: false, follow: false },
};

// Script bloqueante e inofensivo: só lê a preferência de tema salva
// (localStorage 'cc-theme') e aplica a classe em <html> antes da primeira
// pintura, pra não piscar claro→escuro.
const THEME_INIT_SCRIPT = `(function(){try{var t=localStorage.getItem('cc-theme');if(t==='dark'||t==='light'){document.documentElement.classList.add(t);}}catch(e){}})();`;

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
