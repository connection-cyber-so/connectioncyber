# Migração: módulos Diagnóstico Digital, Catálogo de Produtos/Ofertas e Roteiro de Vídeo (origem: cc-commerce-studio)

> Origem: código real avaliado em `J:\BK_connectioncyber\connectioncyber\cc-commerce-studio`
> (auditoria read-only de 2026-08-15, ver `docs/visao-longo-prazo-modulos.md` para o resto do
> que foi encontrado nesse drive). Este documento registra o que foi migrado, o que mudou, e
> como foi verificado — não a auditoria inteira.

## O que foi trazido

O `cc-commerce-studio` tinha 7 "motores" de marketing com IA (feature-sliced: `actions/
mutations/queries/services/types/validations` por feature). Três já foram migrados, em três
rodadas:

1. **Diagnóstico Digital** (0009) — o menor e mais autocontido, piloto do processo.
2. **Catálogo de Produtos e Ofertas** (0010) — Products + Offer Engine. Trazidos juntos porque
   `offers.product_id` é obrigatório no código original — não dava pra migrar um sem o outro.
   `Brands` (marca do produto) ficou de fora: é uma FK opcional em `offers`/`products`, e nenhum
   tenant hoje precisa de múltiplas marcas por conta — fica de próximo incremento.
3. **Roteiro de Vídeo** (0011) — Video Script Engine, depende de `mpi_offers` (`offer_id`
   obrigatório) — só foi possível depois da rodada anterior. Escolhido em vez de Landing Pages
   por ser o mesmo padrão de CRUD+geração por IA já validado duas vezes, sem introduzir a
   complexidade nova de página pública sem autenticação que Landing Pages exigiria.

## Decisão de arquitetura: Workspace = Tenant, 1 pra 1

Confirmada por Joaquim Coelho em 2026-08-15. O código original usava `workspaces` +
`workspace_members` (tabela de membros N:N — um usuário podia pertencer a vários workspaces).
Aqui isso foi **descartado**: reaproveita a tabela `tenants` e a função `current_tenant_id()`
já existentes (lê de `public.users`, 1 usuário = 1 tenant). Nenhuma tabela de membros nova.

## O que mudou do original para cá

| Original (`cc-commerce-studio`) | Aqui (`apps/platform`) |
|---|---|
| `workspace_id` em toda tabela/tipo/query | `tenant_id` |
| `workspaces` + `workspace_members` (RLS via subquery de membro) | `tenants` + `current_tenant_id()` (já existente) |
| `projects` (nome genérico, órfão desde a migration 001 deles) | `mpi_projects` (renomeado — evita colisão semântica com o domínio de e-commerce já existente: `courses`/`products`/`orders`) |
| `diagnostics` | `mpi_diagnostics` |
| Tailwind (`components/ui/*`) | tokens `.pf-*` já usados no `apps/platform` (login/dashboard) — sem introduzir uma segunda linguagem visual num app que acabou de nascer |
| `features/diagnostic-engine/{actions,mutations,queries,services,types,validations}` (6 pastas) | `features/diagnostics/{actions.ts,service.ts,types.ts,validations.ts,components/}` — mesma separação de responsabilidade, sem a indireção de wrappers de 1 linha (mutations/queries só chamavam o service) |
| `products` / `offers` / `video_scripts` | `mpi_products` / `mpi_offers` / `mpi_video_scripts` (mesmo motivo do `mpi_projects` — evita colisão com o catálogo de cursos/produtos já existente da própria ConnectionCyber) |
| `offers.brand_id`, `products.brand_id` (FK para `brands`) | Removido nesta rodada — `brands` não foi migrado, nenhum tenant precisa disso hoje |

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

As três seguem o mesmo padrão: RLS via `current_tenant_id()`/`is_platform_staff()` (mesmo de
`0002`/`0004`), grants explícitos para `authenticated` (mesmo de `0008`), registro no
`module_catalog` (mesmo mecanismo de habilitação por tenant dos módulos existentes). Aplicadas
em **produção e staging** — é só schema, sem dado de cliente (diferente da `0006`, exclusiva de
produção).

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

## Ainda não trazido (backlog)

Os outros 4 motores do `cc-commerce-studio` (Landing Pages, Brands, Workspace genérico) — mesmo
processo, um de cada vez, conforme fizer sentido comercial. Landing Pages é o próximo candidato
natural (também depende de `offers`, já disponível), mas introduz uma peça nova: página pública
sem autenticação (`/lp/[slug]`), que exige decisão de arquitetura própria antes de migrar.
`GEMINI_API_KEY` própria da ConnectionCyber ainda não configurada em nenhum ambiente — sem ela,
"Gerar com IA" cai num rascunho manual em todos os módulos (comportamento herdado do original,
não é regressão).
