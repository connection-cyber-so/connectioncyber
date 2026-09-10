# Evidência — Implementação i18n Perfil A

**Data:** 2026-09-09
**Status:** Aprovado com ressalva de validação visual manual

## Escopo executado

- Fonte única para `pt-BR`, `en-US` e `es-419`.
- Dicionário espanhol latino-americano.
- Restauração segura de `cc-locale` sem alterar o HTML inicial do servidor.
- Atualização dinâmica de `document.documentElement.lang`.
- API textual `t()` separada de `getTranslation()` para coleções.
- Remoção de `any` do contexto de tradução.
- Teste automatizado de paridade, tipos estruturais e valores vazios.
- Seletor PT/EN/ES.
- Configuração ESLint `next/core-web-vitals`.

## Validações

- `npm run test:i18n`: aprovado para três locales.
- `npm run type-check`: aprovado.
- `npm run build`: aprovado; 15 páginas geradas.
- Webpack informou falha de renomeação no cache por `EPERM`, sem impedir compilação.
- `npm run lint`: aprovado, com três avisos preexistentes de uso de `<img>` em `ClientCard`, `Footer` e `Header`.
- Validação visual e persistência no navegador: pendente por indisponibilidade da skill de navegador nesta sessão.

## Risco residual

Existem strings hardcoded em páginas fora dos dicionários; a interface ainda não possui cobertura integral de tradução. O M4 de internacionalização completa permanece bloqueado até inventário e migração dessas strings, revisão humana de `es-419` e teste visual dos três idiomas.
