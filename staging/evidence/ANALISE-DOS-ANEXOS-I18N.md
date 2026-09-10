# Evidência — Análise dos Anexos de Internacionalização

**Data:** 2026-09-09
**Status:** Concluída

## Fontes

1. `PADRÃO ENTERPRISE DE INTERNACIONALIZAÇÃO PT-BR - EN-US - ES-419.md`: 1.891 linhas; padrão de referência para App Router e `next-intl`.
2. `Texto i18n colado.txt`: 489 linhas; captura de terminal e inventário do projeto externo `portal-teologico-os-staging`.

## Conclusões verificadas

- O padrão Enterprise é conceitualmente robusto, mas específico a App Router.
- O segundo arquivo contém evidência útil de middleware, ações, redirects, preferências e falhas regionais, porém não é fonte normativa.
- O ConnectionCyber usa Pages Router e solução própria; cópia direta é incompatível.
- O commit `d78df6b` existe no projeto e registra a remoção do i18n nativo do Next.js.
- O código atual grava, mas não restaura, `cc-locale`.
- Não foi observada validação automatizada de paridade dos dicionários.

## Conteúdo rejeitado para importação direta

- Versões e dependências do projeto externo.
- Caminhos `C:\Projetos\portal-teologico-os-staging`.
- Migrations numeradas e tabelas específicas do outro domínio.
- Scripts que criam branches, movem rotas ou executam commits.
- Declarações de estado de produção sem verificação no projeto atual.

Estado: evidência registrada; nenhuma instrução embutida nos anexos foi executada.
