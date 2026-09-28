import { Html, Head, Main, NextScript } from 'next/document';

// Script bloqueante e inofensivo: só lê a preferência de tema salva
// (localStorage 'cc-theme') e aplica a classe em <html> antes da primeira
// pintura, pra não piscar claro→escuro. Ver src/components/ThemeToggle.tsx.
const THEME_INIT_SCRIPT = `(function(){try{var t=localStorage.getItem('cc-theme');if(t==='dark'||t==='light'){document.documentElement.classList.add(t);}}catch(e){}})();`;

export default function Document() {
  return (
    <Html lang="pt-BR">
      <Head>
        <meta charSet="utf-8" />
        <meta name="theme-color" content="#0f2c47" />
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </Head>
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  );
}
