# Seletor de idioma (PT/EN) — tecnologia e implementação

**Onde aparece:** botão pílula "PT | EN" no cabeçalho do site (`apps/site`), componente
`LanguageSwitcher`, renderizado dentro de `Header.tsx`.

## Qual é a tecnologia

**Não é uma biblioteca de i18n.** Não usa `next-i18next`, `react-intl`, `next-intl`,
`FormatJS` nem nenhum pacote externo de internacionalização. É uma implementação própria
("hand-rolled"), construída só com recursos nativos do React:

- **Context API do React** (`createContext` / `useContext`) para guardar o idioma atual e
  disponibilizá-lo para qualquer componente da árvore sem precisar passar por props.
- **Dicionários estáticos em JSON** (`src/i18n/pt-BR.json`, `src/i18n/en-US.json`), importados
  diretamente no bundle — não são buscados por rede.
- **`localStorage`** do navegador para lembrar a escolha do usuário entre visitas.
- Uma função `t(path)` que resolve caminhos com notação de ponto (ex: `"nav.home"`) dentro do
  dicionário do idioma ativo, sem depender de nenhuma engine de template.

Em uma frase: **é i18n client-side, feito à mão, via Context API — estado em memória +
JSON estático, sem roteamento por URL.**

### Por que não é o i18n nativo do Next.js

O Next.js tem um sistema de i18n embutido (`next.config.js` → `i18n: { locales, defaultLocale }`),
que gera uma URL por idioma (`/pt-BR/...`, `/en-US/...`). Esse recurso **foi usado e depois
removido** deste projeto durante esta mesma sessão de trabalho: ele dobrava o número de páginas
geradas no build (42 em vez de ~16) sem que nada no app realmente navegasse para essas URLs
prefixadas, e foi identificado como a causa mais provável de um erro `NOT_FOUND` na borda da
Vercel após o deploy. A troca de idioma deste site sempre foi feita por estado de React, nunca
por navegação de URL — por isso o i18n nativo do Next era peso morto, e a correção foi
simplesmente removê-lo de `next.config.js` (commit `d78df6b`, "Remove i18n nativo do Next.js").

## Arquitetura

```
LanguageProvider (Context)              LanguageSwitcher (UI)
┌─────────────────────────┐             ┌───────────────────┐
│ locale: 'pt-BR'|'en-US'  │◄───useLanguage()───┤  botão "PT"   │
│ setLocale(locale)        │─────onClick────────►  botão "EN"   │
│ t(path) → string         │             └───────────────────┘
└─────────────────────────┘
        │        ▲
        │        └── localStorage['cc-locale'] (persistência entre sessões)
        ▼
  pt-BR.json / en-US.json (dicionários estáticos, no bundle)
```

Todo componente do site que precisa de texto traduzido chama `useLanguage()` para obter
`t()`, e escreve `t('home.heroTitle')` em vez do texto literal.

## Código

### `src/context/LanguageContext.tsx` — estado, persistência e função de tradução

```tsx
import React, { createContext, useCallback, useContext, useMemo, useState } from 'react';
import ptBR from '@/i18n/pt-BR.json';
import enUS from '@/i18n/en-US.json';

export type Locale = 'pt-BR' | 'en-US';

const dictionaries: Record<Locale, Record<string, any>> = {
  'pt-BR': ptBR,
  'en-US': enUS,
};

interface LanguageContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: (path: string) => any;
}

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined);

// Resolve "nav.home" -> dictionaries[locale].nav.home
function resolvePath(dict: Record<string, any>, path: string): any {
  return path.split('.').reduce<any>((acc, key) => (acc == null ? acc : acc[key]), dict);
}

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>('pt-BR');

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    if (typeof window !== 'undefined') {
      window.localStorage.setItem('cc-locale', next);
      document.documentElement.lang = next; // acessibilidade / SEO
    }
  }, []);

  const t = useCallback(
    (path: string) => {
      const value = resolvePath(dictionaries[locale], path);
      return value ?? path; // fallback: mostra a própria chave se faltar tradução
    },
    [locale]
  );

  const value = useMemo(() => ({ locale, setLocale, t }), [locale, setLocale, t]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error('useLanguage deve ser usado dentro de <LanguageProvider>');
  }
  return ctx;
}
```

### `src/components/LanguageSwitcher.tsx` — o botão pílula PT/EN

```tsx
import React from 'react';
import { useLanguage, Locale } from '@/context/LanguageContext';

const OPTIONS: { value: Locale; label: string }[] = [
  { value: 'pt-BR', label: 'PT' },
  { value: 'en-US', label: 'EN' },
];

export default function LanguageSwitcher() {
  const { locale, setLocale } = useLanguage();

  return (
    <div style={styles.wrapper} role="group" aria-label="Seletor de idioma">
      {OPTIONS.map((opt) => (
        <button
          key={opt.value}
          onClick={() => setLocale(opt.value)}
          aria-pressed={locale === opt.value}
          style={{ ...styles.btn, ...(locale === opt.value ? styles.btnActive : {}) }}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  wrapper: { display: 'inline-flex', border: '1px solid var(--cc-border)', borderRadius: 999, overflow: 'hidden' },
  btn: { padding: '6px 12px', fontSize: '0.8rem', fontWeight: 700, background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--cc-text-muted)' },
  btnActive: { background: 'var(--cc-primary)', color: '#fff' },
};
```

### Onde é ligado

`src/pages/_app.tsx` envolve todo o app com `<LanguageProvider>`, e `Header.tsx` renderiza
`<LanguageSwitcher />` — é isso que faz o botão aparecer em toda página.

## Como usar em uma página nova

```tsx
const { t } = useLanguage();
<h1>{t('home.heroTitle')}</h1>
```
A chave `home.heroTitle` precisa existir em **ambos** `pt-BR.json` e `en-US.json` — se faltar
em um dos dois, o fallback (`?? path`) mostra a própria chave (`"home.heroTitle"`) na tela em
vez de quebrar a página. É um sinal visual de tradução faltando, não um erro.

## Limitações conhecidas (trade-offs da escolha)

- **Sem URL por idioma** — não dá para linkar diretamente para a versão em inglês de uma
  página (`/en-US/servicos` não existe). Se isso vier a ser necessário (SEO multilíngue, por
  exemplo), é uma mudança de arquitetura, não um ajuste pequeno.
- **Sem tradução no servidor** — a primeira renderização (HTML enviado pelo Next.js) é sempre
  em `pt-BR`; a troca para inglês só acontece depois que o JavaScript carrega no navegador e o
  Context reidrata a preferência salva. Efeito prático: um visitante que sempre usa o site em
  inglês vê um piscar rápido de português antes do idioma trocar.
- **Todo o texto de ambos os idiomas vai no bundle** — os dois arquivos JSON são carregados
  sempre, não só o idioma ativo (o impacto é pequeno hoje, mas cresce se o site ganhar muito
  mais conteúdo).
