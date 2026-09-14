# ADR-002 — Estratégia de Internacionalização

**Status:** Aceito — Perfil A autorizado
**Data:** 2026-09-09
**Decisores:** Joaquim / ConnectionCyber

## Contexto

O projeto utiliza Next.js 14 Pages Router e i18n client-side próprio para `pt-BR` e `en-US`. Foi fornecido um padrão Enterprise para App Router, `next-intl` e `es-419`. A adoção direta exigiria migração transversal e poderia reintroduzir problemas de rotas e Vercel já evitados pelo commit `d78df6b`.

## Decisão proposta

Manter temporariamente o Perfil A, corrigir persistência, tipagem e paridade, e adicionar `es-419` somente após validação das traduções. Avaliar Perfil B por POC isolada apenas quando existir requisito aprovado de SEO multilíngue, URL localizada, renderização no servidor ou conteúdo dinâmico em escala.

## Consequências

Benefícios: menor risco imediato, correção da dívida atual e evolução incremental. Limitações: ausência de URLs por locale, SEO multilíngue limitado e primeira renderização em `pt-BR`. A migração futura continuará possível, mas exigirá plano próprio de router e compatibilidade.

## Alternativas

1. Migrar imediatamente para App Router/`next-intl`: rejeitada nesta etapa por risco e falta de requisito aprovado.
2. Manter implementação atual sem correções: rejeitada por persistência incompleta e tipagem fraca.
3. Implementar Perfil A robusto e avaliar Perfil B: recomendada.

## Critério para aprovação

A decisão deve ser revista pelo responsável do produto, arquitetura, SEO e segurança antes de qualquer mudança de router ou nova dependência.

## Registro de execução

Em 2026-09-09, o Perfil A foi autorizado e implementado com `es-419`, persistência segura, fonte única de locales, separação entre tradução textual e estruturada, teste de paridade e configuração ESLint. O Perfil B continua condicionado a novo ADR ou revisão deste documento.
