# Evidência — Implementação i18n Perfil A

**Data:** 2026-09-09
**Status:** Aprovado para a branch `staging`; promoção para produção condicionada à validação visual e à cobertura integral das traduções

## Escopo executado

- Fonte única para `pt-BR`, `en-US` e `es-419`.
- Dicionário espanhol latino-americano.
- Restauração segura de `cc-locale` sem alterar o HTML inicial do servidor.
- Atualização dinâmica de `document.documentElement.lang`.
- API textual `t()` separada de `getTranslation()` para coleções.
- Remoção de `any` do contexto de tradução.
- Teste automatizado de paridade, tipos estruturais e valores vazios.
- Seletor PT/EN/ES.
- Integração com a configuração ESLint vigente no repositório remoto.
- Atualização de segurança do Next.js `15.5.21` para `15.5.25`.
- Atualização forçada de `sharp` para `0.35.4` e resolução de `js-yaml` para `4.3.2`.

## Validações

- `npm run test:i18n`: aprovado para três locales.
- `npm run type-check`: aprovado.
- `npm run lint`: aprovado; somente aviso de descontinuação do comando `next lint`.
- `npm audit --audit-level=high`: aprovado; zero vulnerabilidades conhecidas.
- `npm run build`: aprovado com Node.js `22.23.2` e Next.js `15.5.25`; 14 páginas estáticas processadas e rotas dinâmicas compiladas.
- Webpack registrou apenas alerta de desempenho do cache por serialização de strings grandes, sem falha de compilação.
- Validação visual e persistência no navegador: pendente por indisponibilidade da skill de navegador nesta sessão.

## Risco residual

Existem strings hardcoded em páginas fora dos dicionários; a interface ainda não possui cobertura integral de tradução. O M4 de internacionalização completa permanece bloqueado até inventário e migração dessas strings, revisão humana de `es-419` e teste visual dos três idiomas.
