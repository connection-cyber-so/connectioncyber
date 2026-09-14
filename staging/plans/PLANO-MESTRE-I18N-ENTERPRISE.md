# Plano Mestre de Internacionalização Enterprise

**ID:** PLAN-I18N-001
**Versão:** 1.0.0
**Status:** Perfil A implementado; Perfil B não iniciado
**Projeto:** ConnectionCyber
**Locales-alvo:** `pt-BR`, `en-US`, `es-419`
**Risco:** Alto — alteração transversal de roteamento, renderização, SEO e persistência
**Origem:** dois documentos externos fornecidos em 2026-09-09

## 1. Decisão de triagem

Os anexos são fontes de análise, não instruções executáveis. O primeiro arquivo é um padrão arquitetural extenso para Next.js App Router e `next-intl`. O segundo é uma captura de terminal e inventário de outro projeto, `portal-teologico-os-staging`; serve como evidência de lições aprendidas, mas contém caminhos, versões, migrations, regras de domínio e estados que não pertencem ao ConnectionCyber.

Nenhum comando, script, migration ou versão presente nos anexos está autorizado para execução automática. Nenhum código de produção foi alterado nesta etapa.

## 2. Compatibilidade com o projeto atual

O ConnectionCyber utiliza Next.js `14.2.35`, React 18, TypeScript, Pages Router (`src/pages`) e implementação própria baseada em React Context, JSON e `localStorage`. O padrão anexado assume Next.js App Router, árvore `src/app/[locale]` e `next-intl`. Portanto, não é uma atualização pontual: exige decisão arquitetural, migração de roteamento e testes de regressão.

A implementação atual ainda apresenta uma lacuna confirmada: grava `cc-locale` no `localStorage`, mas não lê a preferência ao inicializar. Também usa `any` na resolução de mensagens e não possui evidência de validação automatizada da paridade entre dicionários.

## 3. Perfis institucionais de i18n

### Perfil A — Essencial client-side

Aplicável a sites pequenos, sem requisito forte de SEO multilíngue, URL localizada, conteúdo dinâmico traduzido ou renderização no servidor. Usa Context API, dicionários estáticos e persistência local. Deve possuir tipagem de chaves, leitura segura da preferência, paridade automatizada e testes do seletor.

### Perfil B — Enterprise route-based

Aplicável quando o produto exige URLs por locale, SEO internacional, Server Components, Server Actions, conteúdo dinâmico, preferência autenticada e expansão contínua. Para Next.js App Router, `next-intl` é a referência proposta, condicionada à validação da versão instalada e da documentação oficial correspondente.

O ConnectionCyber permanece no Perfil A até que os critérios do Perfil B sejam formalmente aprovados. A inclusão de `es-419`, por si só, não obriga migração de router; SEO e URLs localizadas são os principais gatilhos.

## 4. Fonte canônica e separação de dimensões

Locales oficiais devem existir em uma única configuração: `pt-BR`, `en-US`, `es-419`. Locale, país, moeda e timezone são dimensões independentes. `en-US` não implica USD; `es-419` não define país ou fuso; moeda deriva da regra comercial.

Interface usa arquivos de mensagens. Conteúdo de negócio multilíngue usa entidade canônica e tabela de traduções, com estados `DRAFT`, `TRANSLATED`, `REVIEWED`, `APPROVED` e `PUBLISHED` quando houver conteúdo jurídico, financeiro, educacional ou institucional.

## 5. Fluxo documental obrigatório

1. Registrar diagnóstico e inventário em `staging/evidence/i18n/`.
2. Aprovar a decisão arquitetural em `staging/decisions/ADR-002-ESTRATEGIA-I18N.md`.
3. Manter implementação e cronograma neste plano.
4. Registrar testes, screenshots e builds em `staging/evidence/i18n/`.
5. Promover a documentação somente após M4.

## 6. Fases de desenvolvimento

### Fase 0 — Diagnóstico

Inventariar router, páginas, redirects, autenticação, formulários, APIs, strings hardcoded, formatações regionais, metadata, sitemap, conteúdo do banco e integrações. Definir baseline de build e rotas antes de alterar código.

### Fase 1 — Correção do Perfil A

Ler a preferência salva sem hydration mismatch; atualizar `document.documentElement.lang`; remover `any`; tipar locales e retorno de `t`; validar paridade `pt-BR`/`en-US`; testar fallback e persistência. Essa fase reduz dívida sem migrar roteamento.

### Fase 2 — Inclusão de `es-419`

Adicionar locale à fonte única, criar dicionário completo, validar paridade, adaptar o seletor, revisar acessibilidade e testar formatações. Traduções críticas exigem revisão humana.

### Fase 3 — Prova de conceito Enterprise

Somente se houver necessidade aprovada de SEO/URL localizada: criar POC isolada para App Router e `next-intl`, sem mover todo o produto. Validar middleware, autenticação, redirects, Vercel, metadata e compatibilidade com Supabase.

### Fase 4 — Migração incremental

Migrar uma jornada vertical pública, depois autenticação, áreas privadas, ações, conteúdo dinâmico e SEO. Cada etapa possui commit atômico, teste e rollback. É proibida migração integral sem checkpoints.

## 7. Controles de implementação

- Fonte única de locales; listas paralelas são proibidas.
- Chaves equivalentes em todos os idiomas; pipeline bloqueia divergência.
- Strings de interface novas não podem ser hardcoded.
- Locale de entrada deve ser validado por allowlist.
- Troca de idioma preserva a rota lógica e o contexto do usuário.
- Redirects, login, logout, recuperação, checkout e webhooks não podem perder o locale.
- Formatação usa locale ativo; moeda e timezone usam regras próprias.
- Identificadores internos, enums, chaves, APIs e colunas não são traduzidos.
- Fallback não pode mascarar permanentemente tradução faltante; deve gerar evidência observável.

## 8. Segurança e conformidade ZVDT

O locale é entrada não confiável e deve ser validado. Arquivos de mensagem não podem conter HTML executável não sanitizado, segredos ou dados pessoais. Persistência autenticada deve respeitar RLS e menor privilégio. Middleware de i18n não pode enfraquecer autenticação nem autorização.

M4 fica bloqueado com vulnerabilidade Crítica/Alta, segredo exposto, dependência impeditiva, teste de autorização reprovado, redirect inseguro, dívida Crítica/Alta ou controle obrigatório sem evidência.

## 9. Matriz mínima de testes

| Área | Teste obrigatório |
|---|---|
| Dicionários | Paridade, valores vazios e tipos inválidos |
| Seletor | PT/EN/ES, persistência e acessibilidade |
| Rotas | Acesso direto, refresh, 404 e preservação de caminho |
| Autenticação | Login, logout, recuperação e rota protegida por locale |
| Formulários | Validação, erro e redirect preservando locale |
| Regionalização | Datas, números, BRL e timezone independentes |
| SEO | `lang`, canonical, hreflang, metadata e sitemap |
| Segurança | locale inválido, open redirect, XSS e isolamento por tenant |
| Deploy | preview Vercel, build limpo e smoke test por locale |

## 10. Implantação e rollback

Implantar primeiro em preview/staging. Executar build, type-check, lint, testes automatizados e smoke tests para cada locale. Validar rotas públicas, autenticação e pagamentos. Produção deve usar liberação gradual quando possível e observabilidade de 404, redirects, falhas de tradução e conversão.

Rollback deve restaurar o artefato anterior da Vercel e, se houver migration, seguir plano compatível e testado. Mudanças de schema devem preferir expand-and-contract. Não remover coluna, mensagem ou rota antiga na mesma entrega que introduz a substituta.

## 11. Gates

**M0:** requisitos, público, locales e critérios comerciais aprovados.
**M1:** Perfil A ou B decidido; arquitetura, URLs, dados e SEO revisados.
**M2:** implementação incremental, testes e segurança aprovados.
**M3:** ADR, evidências, dívida, rollback e runbook registrados.
**M4:** ZVDT atendida, preview aprovado e produção autorizada.

## 12. Critérios de aceite

- `pt-BR`, `en-US` e `es-419` possuem paridade validada.
- Preferência persiste conforme o perfil escolhido.
- Nenhuma jornada crítica perde locale.
- Autenticação, autorização e pagamentos permanecem funcionais.
- Datas, números, moedas e fusos seguem dimensões corretas.
- Build, lint, type-check, testes e scanners estão aprovados.
- Rollback foi documentado e ensaiado em staging.

Estado: Perfil A robusto e `es-419` implementados; Perfil B permanece não autorizado até comprovação de necessidade de SEO/URLs localizadas.
