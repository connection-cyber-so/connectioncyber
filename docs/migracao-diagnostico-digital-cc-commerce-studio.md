# Migração: módulos de marketing com IA (origem: cc-commerce-studio)

> Origem: código real avaliado em `J:\BK_connectioncyber\connectioncyber\cc-commerce-studio`
> (auditoria read-only de 2026-08-15, ver `docs/visao-longo-prazo-modulos.md` para o resto do
> que foi encontrado nesse drive). Este documento registra o que foi migrado, o que mudou, e
> como foi verificado — não a auditoria inteira.

## O que foi trazido

O `cc-commerce-studio` tinha 7 "motores" de marketing com IA (feature-sliced: `actions/
mutations/queries/services/types/validations` por feature). Quatro já foram migrados, em quatro
rodadas:

1. **Diagnóstico Digital** (0009) — o menor e mais autocontido, piloto do processo.
2. **Catálogo de Produtos e Ofertas** (0010) — Products + Offer Engine. Trazidos juntos porque
   `offers.product_id` é obrigatório no código original — não dava pra migrar um sem o outro.
   `Brands` (marca do produto) ficou de fora: é uma FK opcional em `offers`/`products`, e nenhum
   tenant hoje precisa de múltiplas marcas por conta — fica de próximo incremento.
3. **Roteiro de Vídeo** (0011) — Video Script Engine, depende de `mpi_offers` (`offer_id`
   obrigatório) — só foi possível depois da rodada anterior. Escolhido antes de Landing Pages
   por ser o mesmo padrão de CRUD+geração por IA já validado duas vezes, sem introduzir a
   complexidade nova de página pública sem autenticação que Landing Pages exigiria.
4. **Landing Pages** (0012) — a primeira peça pública de todo este trabalho. Trazida por
   último, de propósito: as três rodadas anteriores só tinham telas internas (equipe logada);
   esta tem uma página que o **lead do cliente** acessa sem login nenhum — decisão de
   arquitetura própria, decidida com Joaquim antes de implementar (ver seção dedicada abaixo).

## Decisão de arquitetura: Workspace = Tenant, 1 pra 1

Confirmada por Joaquim Coelho em 2026-08-15. O código original usava `workspaces` +
`workspace_members` (tabela de membros N:N — um usuário podia pertencer a vários workspaces).
Aqui isso foi **descartado**: reaproveita a tabela `tenants` e a função `current_tenant_id()`
já existentes (lê de `public.users`, 1 usuário = 1 tenant). Nenhuma tabela de membros nova.

## Decisão de arquitetura: onde a landing page publicada é servida

Decidida com Joaquim Coelho em 2026-08-15, antes de qualquer código. `apps/platform` é
exclusivamente interno desde a Fase 1 ("Só a equipe entra aqui; clientes finais usam
`apps/site`") — Landing Pages é o primeiro módulo com uma tela que **não** é pra equipe: é a
página que o lead vê ao clicar num anúncio.

Duas opções foram avaliadas:

- **Opção A** — rota pública dentro do próprio `apps/platform`, com exceção no middleware.
  Menos trabalho agora, mas fura pela primeira vez a regra "platform é só equipe".
- **Opção B** (escolhida) — a equipe continua criando/editando em `apps/platform`; quem vê a
  página publicada acessa via **`apps/site`**, que já é 100% público desde o início.
  `apps/platform` continua sem nenhuma rota sem login.

Consequência técnica: `apps/site` (Pages Router, `pages/lp/[slug].tsx`) lê a tabela
`mpi_landing_pages` direto do Supabase com a chave anônima — nenhum código novo de auth, o
middleware do site já só protege `/membros`, `/lp/*` ficou público automaticamente.

### Correção de avaliação: slug não é um bug, é por design

Na primeira leitura do schema original, `unique(slug)` **global** (sem `workspace_id`/
`tenant_id`) pareceu um problema — dois clientes concorrendo pelo mesmo slug. Reavaliando com a
decisão acima: como a URL pública é sempre sob o domínio da própria ConnectionCyber
(`connectioncyber.com.br/lp/<slug>`), um namespace compartilhado é o comportamento correto —
o mesmo modelo de qualquer construtor de landing page (Lead Pages, Unbounce, Carrd). Mantido
único global na migration `0012`, igual ao original.

## O que mudou do original para cá

| Original (`cc-commerce-studio`) | Aqui (`apps/platform`) |
|---|---|
| `workspace_id` em toda tabela/tipo/query | `tenant_id` |
| `workspaces` + `workspace_members` (RLS via subquery de membro) | `tenants` + `current_tenant_id()` (já existente) |
| `projects` (nome genérico, órfão desde a migration 001 deles) | `mpi_projects` (renomeado — evita colisão semântica com o domínio de e-commerce já existente: `courses`/`products`/`orders`) |
| `diagnostics` | `mpi_diagnostics` |
| Tailwind (`components/ui/*`) | tokens `.pf-*` já usados no `apps/platform` (login/dashboard) — sem introduzir uma segunda linguagem visual num app que acabou de nascer |
| `features/diagnostic-engine/{actions,mutations,queries,services,types,validations}` (6 pastas) | `features/diagnostics/{actions.ts,service.ts,types.ts,validations.ts,components/}` — mesma separação de responsabilidade, sem a indireção de wrappers de 1 linha (mutations/queries só chamavam o service) |
| `products` / `offers` / `video_scripts` / `landing_pages` | `mpi_products` / `mpi_offers` / `mpi_video_scripts` / `mpi_landing_pages` (mesmo motivo do `mpi_projects` — evita colisão com o catálogo de cursos/produtos já existente da própria ConnectionCyber) |
| `offers.brand_id`, `products.brand_id` (FK para `brands`) | Removido nesta rodada — `brands` não foi migrado, nenhum tenant precisa disso hoje |
| Rota pública `app/lp/[slug]` dentro do próprio app (App Router) | `apps/site/pages/lp/[slug].tsx` (Pages Router) — app diferente, ver decisão de arquitetura acima |

### Achado de segurança corrigido durante a migração

No original, as Server Actions liam `tenant_id` (lá, `workspace_id`) direto de
`formData.get("workspace_id")` — um campo hidden do formulário, ou seja, dado vindo do
cliente. O RLS deles ainda protegia (a escrita falharia se o usuário não fosse membro do
workspace), mas não seguia o padrão "servidor deriva o tenant da sessão" já adotado neste
projeto. **Aqui, nenhuma Server Action recebe tenant_id de formulário** — todas chamam
`requireCurrentTenantId()` (`apps/platform/src/lib/tenant.ts`), que lê a sessão no servidor.

## Migrations

- **`0009_modulo_diagnostico_digital.sql`** — `mpi_projects` + `mpi_diagnostics`, módulo
  `diagnostico-digital-ia` no `module_catalog`.
- **`0010_modulo_catalogo_produtos_ofertas.sql`** — `mpi_products` + `mpi_offers`
  (`mpi_offers.product_id` referencia `mpi_products`), módulo `catalogo-produtos-ofertas-ia`.
- **`0011_modulo_roteiro_video.sql`** — `mpi_video_scripts` (`offer_id` referencia
  `mpi_offers`), módulo `roteiro-video-ia`.
- **`0012_modulo_landing_pages.sql`** — `mpi_landing_pages` (`offer_id` referencia
  `mpi_offers`, `slug` único global), módulo `landing-pages`.

As quatro seguem o mesmo padrão: RLS via `current_tenant_id()`/`is_platform_staff()` (mesmo de
`0002`/`0004`), grants explícitos para `authenticated` (mesmo de `0008`), registro no
`module_catalog` (mesmo mecanismo de habilitação por tenant dos módulos existentes). Aplicadas
em **produção e staging** — é só schema, sem dado de cliente (diferente da `0006`, exclusiva de
produção).

A `0012` tem uma peça a mais que as outras três: `grant select on mpi_landing_pages to anon` —
primeira tabela do projeto com leitura pública real (apps/site consulta sem sessão, role `anon`
do Supabase), escopo estritamente limitado pela policy "público vê landing pages publicadas"
(só `status = 'published'`).

## Verificação (não simulada)

Criado um usuário de teste real no Supabase de staging (`teste-diagnostico@connectioncyber.local`,
auto-provisionado no tenant ConnectionCyber pelo trigger `handle_new_user()` já existente),
usado para testar o fluxo completo pela UI:

- ✅ Acesso a `/diagnostics` sem sessão redireciona para `/login` (middleware).
- ✅ `getOrCreateMpiProject` criou o projeto MPI do tenant na primeira visita.
- ✅ Criar diagnóstico pelo formulário — gravou de verdade em `mpi_diagnostics`, RLS
  validou `tenant_id = current_tenant_id()`, tela atualizou com o novo card.
- ✅ Editar diagnóstico (título) pela UI — `updateDiagnosticAction` gravou e a tela atualizou.
- ◐ Excluir diagnóstico: código simétrico ao de editar (mesma checagem de RLS), mas o clique
  não pôde ser confirmado ponta-a-ponta pela ferramenta de automação porque usa
  `window.confirm()` nativo do navegador, que a automação não consegue responder — revisão de
  código confirma que segue o mesmo padrão já validado em criar/editar.
- Todos os dados de teste (diagnóstico, projeto MPI, usuário) foram apagados do staging ao
  final da verificação — nada de teste ficou para trás.

**Catálogo de Produtos e Ofertas** — segundo usuário de teste
(`teste-catalogo@connectioncyber.local`), mesmo processo:

- ✅ `/products` — cadastrar produto pela UI grava em `mpi_products`, tela atualiza.
- ✅ `/offers` — formulário lista automaticamente o produto recém-criado; "Gerar copy com IA"
  chama `generateOfferCopyAction`, que busca o produto **sob RLS da sessão do usuário**
  (`getProductById` só enxerga produtos do próprio tenant) e devolve o rascunho manual
  corretamente referenciando o nome do produto certo.
- ✅ Criar oferta pela UI — grava em `mpi_offers` com `status: 'generated'` (copy não-vazia),
  vínculo com `product_id` correto.
- Todos os dados de teste (oferta, produto, usuário) foram apagados do staging ao final.

**Roteiro de Vídeo** — terceiro usuário de teste (`teste-video@connectioncyber.local`), mesmo
processo, encadeando os três módulos: produto → oferta → roteiro:

- ✅ Produto criado em `/products`, oferta criada em `/offers` referenciando esse produto.
- ✅ `/video-scripts` — a oferta recém-criada já aparece pré-selecionada no formulário.
- ✅ "Gerar roteiro com IA" chama `generateVideoScriptAction`, que busca a oferta por id e o
  produto via `offer.product_id` (ambos **sob RLS da sessão**), e devolve o rascunho manual
  referenciando corretamente o título da oferta.
- ✅ Criar roteiro pela UI — grava em `mpi_video_scripts` com `offer_id` correto.
- Produto, oferta, roteiro e usuário de teste foram todos apagados do staging ao final.

**Landing Pages** — quarto usuário de teste (`teste-lp@connectioncyber.local`), encadeando
produto → oferta → landing page → **acesso público real, sem sessão nenhuma**:

- ✅ Produto e oferta criados normalmente em `apps/platform`.
- ✅ `/landing-pages` — criar como rascunho grava em `mpi_landing_pages` com `offer_id` correto;
  slug validado (minúsculas/números/hífens).
- ✅ Botão "Publicar" muda `status` para `published` pela UI — confirmado (o card passou a
  mostrar o link público e o botão virou "Despublicar").
- ✅ **A página publicada foi acessada em `apps/site` (`/lp/teste-auditoria-lgpd-2026`), em
  processo separado, sem nenhum cookie/sessão de login — carregou o título e o conteúdo reais**,
  provando que a Opção B (site serve o público) funciona de ponta a ponta.
- ✅ Despublicar testado por manipulação direta do `status` (o clique no botão "Despublicar" não
  pôde ser reconfirmado na UI por uma instabilidade pontual da ferramenta de automação nesta
  sessão — o mesmo código de "Publicar", já confirmado, é usado para os dois sentidos): com
  `status = 'draft'`, a mesma URL em `apps/site` passou a devolver `404` — confirma que a RLS
  pública depende só do `status`, como projetado.
- Landing page, oferta, produto e usuário de teste foram todos apagados do staging ao final.

## Ainda não trazido (backlog)

Os últimos 2 motores do `cc-commerce-studio` (Brands, Workspace genérico) — Workspace genérico
não se aplica mais (substituído pelo modelo de tenant). Brands é uma FK opcional que nenhum
tenant real precisa hoje; entra se algum cliente pedir múltiplas marcas na mesma conta.
`GEMINI_API_KEY` própria da ConnectionCyber ainda não configurada em nenhum ambiente — sem ela,
"Gerar com IA" cai num rascunho manual nos módulos que geram conteúdo (comportamento herdado do
original, não é regressão).
