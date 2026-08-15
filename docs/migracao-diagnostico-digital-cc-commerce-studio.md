# Migração: módulo Diagnóstico Digital (origem: cc-commerce-studio)

> Origem: código real avaliado em `J:\BK_connectioncyber\connectioncyber\cc-commerce-studio`
> (auditoria read-only de 2026-08-15, ver `docs/visao-longo-prazo-modulos.md` para o resto do
> que foi encontrado nesse drive). Este documento registra o que foi migrado, o que mudou, e
> como foi verificado — não a auditoria inteira.

## O que foi trazido

O `cc-commerce-studio` tinha 7 "motores" de marketing com IA (feature-sliced: `actions/
mutations/queries/services/types/validations` por feature). Só um foi migrado agora — o
**Diagnóstico Digital** — escolhido por ser o menor e mais autocontido, servindo de piloto do
processo antes de trazer os outros 6.

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

### Achado de segurança corrigido durante a migração

No original, as Server Actions liam `tenant_id` (lá, `workspace_id`) direto de
`formData.get("workspace_id")` — um campo hidden do formulário, ou seja, dado vindo do
cliente. O RLS deles ainda protegia (a escrita falharia se o usuário não fosse membro do
workspace), mas não seguia o padrão "servidor deriva o tenant da sessão" já adotado neste
projeto. **Aqui, nenhuma Server Action recebe tenant_id de formulário** — todas chamam
`requireCurrentTenantId()` (`apps/platform/src/lib/tenant.ts`), que lê a sessão no servidor.

## Migration `0009_modulo_diagnostico_digital.sql`

Cria `mpi_projects` e `mpi_diagnostics` com RLS via `current_tenant_id()`/`is_platform_staff()`
(mesmo padrão de `0002`/`0004`), grants explícitos para `authenticated` (mesmo padrão de
`0008`), e registra o módulo `diagnostico-digital-ia` no `module_catalog` (mesmo mecanismo de
habilitação por tenant já usado pelos módulos existentes). Aplicada em **produção e staging**
— é só schema, sem dado de cliente (diferente da `0006`, que continua exclusiva de produção).

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

## Ainda não trazido (backlog)

Os outros 6 motores do `cc-commerce-studio` (Offer Engine, Landing Pages, Video Script Engine,
Brands, Products, Workspace genérico) — mesmo processo, um de cada vez, conforme fizer sentido
comercial. `GEMINI_API_KEY` própria da ConnectionCyber ainda não configurada em nenhum
ambiente — sem ela, "Gerar diagnóstico com IA" cai num rascunho manual (comportamento herdado
do original, não é regressão).
