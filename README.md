# connectioncyber — ConnectionCyberSO

**Tecnologia que traz conhecimento e gestão.**
Monorepo de produção (branch `main`) da ConnectionCyber — Assessoria e Treinamento Tecnológico.
Gabriel Batista de Assis Soares Coelho — MEI · CNPJ 13.348.881/0001-88.

Este README é o mapa rápido do repositório. Decisões de arquitetura e o roteiro completo estão
em `docs/parecer-tecnico-arquitetura.md`; os achados da auditoria multi-projeto e o que já foi
trazido de outros projetos do ecossistema estão em `docs/auditoria-ecossistema-connectioncyberos.md`.

## Estrutura

```
connectioncyber/
├─ apps/
│  ├─ site/           site institucional — Next.js 14/TS, Pages Router (ver apps/site/README.md)
│  └─ platform/        ConnectionCyberSO (ERP/CRM/SaaS multi-tenant) — Next.js 14/TS, App Router
│                       (ver apps/platform/README.md) — Fase 1 concluída, sem conteúdo ainda
├─ packages/
│  └─ core/            regras de negócio compartilhadas entre tenants — ainda não iniciado
├─ supabase/
│  ├─ migrations/       schema único do projeto Supabase (multi-tenant via tenant_id + RLS)
│  └─ functions/        Edge Functions (lookup-cnpj)
├─ docs/                documentação do projeto — único local de armazenamento: os briefings
│                       originais (`Connection Cyber Site.txt`, `prompt geral.txt`) e os
│                       documentos técnicos (parecer, auditoria, metodologia) vivem juntos aqui
└─ logo/                identidade visual (logosf.png é o arquivo oficial)
```

Ambiente de desenvolvimento (staging) é um **segundo clone** deste mesmo repositório, na
branch `staging`, em `F:\Projetos\connectioncyber-staging` — não uma pasta dentro deste
diretório.

> **`docs/` só existe na branch `main` (produção).** Era duplicado em `staging` — mesmo
> conteúdo, duas cópias. Consolidado em 2026-08-14: produção é a fonte única de documentação;
> `connectioncyber-staging` não versiona `docs/` nem `documentos/`. Para consultar, use esta
> pasta ou a branch `main` no GitHub.

## Decisões de arquitetura confirmadas

- **Multi-tenant**: 1 projeto Supabase único (`qfggetvashdxyuvlhihq`), isolamento por
  `tenant_id` + Row Level Security. Nenhum cliente novo gera projeto/repositório/pasta —
  vira uma linha na tabela `tenants`.
- **Staging**: clone irmão do repositório, não aninhado.
- **Site**: parte deste monorepo (`apps/site`), não um projeto separado.
- **Stack por app, não por monorepo**: `apps/site` é Pages Router (site institucional, sem dado
  sensível de tenant); `apps/platform` é **App Router** (decidido em 2026-08-15) — painel que
  lida com dado real de cliente, Server Components consultam o Supabase direto no servidor sem
  API route intermediária a esquecer de proteger, alinhado ao padrão do resto do ecossistema
  auditado. Não há necessidade dos dois convergirem — ver `apps/platform/README.md`.

## Status

- [x] `apps/site` construído e validado (`npm run build` limpo).
- [x] Logo oficial e paleta de marca corrigidas (`#F6851F`/`#F8961D`/`#E01F27`/`#CA2127`/
  `#2C9C48`/`#4CB853`/`#28A992`/`#1E9680`).
- [x] Página `/login` e middleware de proteção de rota (`apps/site/src/middleware.ts`) — corrige
  o hang de `/membros` encontrado na validação local.
- [x] Repositório Git inicializado, branches `main` e `staging` publicadas no GitHub
  (`connection-cyber-so/connectioncyber`).
- [x] `supabase link` executado — projeto `connectioncyber` (`qfggetvashdxyuvlhihq`) vinculado.
- [x] Schema aplicado no projeto real: `0001_init_schema` a `0008_corrige_escopo_grants_authenticated`
  (multi-tenant, auto-provisioning, catálogo de módulos, dados cadastrais, grants).
- [x] Edge Function `lookup-cnpj` implantada e testada (consulta BrasilAPI por CNPJ).
- [x] **10 tenants reais povoados** — clientes com contrato ativo, confirmados por Joaquim Coelho,
  dado cadastral via `lookup-cnpj`. Mais 7 empresas confirmadas no pipeline, aguardando CNPJ. Ver
  `docs/metodologia-povoamento-tenant-cnpj-cnae`.
- [x] Vercel conectado — deploy de produção validado.
- [x] **Segundo projeto Supabase criado para staging** (`ozvylnaipubrmaadikvk`) — schema completo
  aplicado (todas as migrations exceto `0006`, que só tem dado de cliente real), `lookup-cnpj`
  implantada lá também. `connectioncyber-staging` vinculado a esse projeto.
- [x] **Variáveis de ambiente da Vercel configuradas por ambiente**: `Production` → Supabase de
  produção (`qfggetvashdxyuvlhihq`), `Preview` (cobre a branch `staging`) → Supabase de staging
  (`ozvylnaipubrmaadikvk`). Local (`.env.local`) recomenda-se apontar sempre para staging, nunca
  para produção — mesma convenção documentada no `food-service-os`.
- [x] **Produção e staging validados ao vivo na Vercel** (`connectioncyber.vercel.app` retorna 200,
  todas as rotas testadas). Causa raiz de um `NOT_FOUND` persistente encontrada e corrigida:
  **Project Settings → Build and Deployment → Framework Preset estava em "Other"**, não "Next.js"
  — o Root Directory (`apps/site`) sempre esteve certo, o build sempre teve sucesso, mas a Vercel
  não aplicava o roteamento de páginas do Next.js na hora de servir. Corrigido trocando o preset
  para "Next.js" e disparando um novo deploy (mudança de preset não redeploya sozinha).
- [ ] **Pendente (1 clique manual no Dashboard)**: ativar `custom_access_token_hook` em
  Authentication → Hooks — https://supabase.com/dashboard/project/qfggetvashdxyuvlhihq/auth/hooks
- [x] **`apps/platform` iniciado — Fase 1 concluída** (Next.js 14 + App Router, decisão registrada
  em `apps/platform/README.md`): esqueleto + login de equipe funcionando, testado de ponta a ponta
  contra o Supabase de staging real. `apps/site` continua Pages Router — sem necessidade de
  convergência entre os dois apps.
- [x] **4 módulos de negócio migrados de `cc-commerce-studio`** (avaliado em auditoria read-only
  de `J:\BK_connectioncyber`, ver `docs/migracao-diagnostico-digital-cc-commerce-studio.md`):
  **Diagnóstico Digital (IA)** (migration `0009`), **Catálogo de Produtos e Ofertas (IA)**
  (migration `0010`), **Roteiro de Vídeo (IA)** (migration `0011`) e **Landing Pages** (migration
  `0012`). Decisão "workspace = tenant, 1 pra 1" confirmada por Joaquim; falha de segurança do
  original (tenant vindo de formulário) corrigida em todos — o tenant sempre vem da sessão.
  **Landing Pages é a primeira peça pública** deste trabalho — decisão de arquitetura própria
  (decidida com Joaquim antes de implementar): gestão em `apps/platform`, página publicada
  servida por `apps/site` (`/lp/[slug]`, sem login), mantendo `apps/platform` 100% interno.
  Migrations aplicadas em produção e staging. Testados de ponta a ponta com usuários reais de
  staging (criar/editar diagnóstico, cadastrar produto, gerar e salvar oferta, gerar e salvar
  roteiro de vídeo, publicar landing page e acessá-la em `apps/site` sem sessão nenhuma).
- [x] **GitHub desbloqueado** — todos os commits pendentes enviados; `main` sincronizado com
  `origin/main`.
- [x] **`apps/platform` Fase 6 — Lista de tenants** (`/tenants`, só leitura): primeira vez que os
  clientes reais e os módulos habilitados de cada um ficam visíveis fora do Supabase Table Editor.
  Testado com um quinto usuário real de staging com papel de equipe (`admin` em `user_roles`).
  Ver `apps/platform/README.md`.
- [x] **`apps/platform` — layout compartilhado + rename para ConnectionCyber**: topbar + menu
  lateral + rodapé viraram um único `layout.tsx` (route group `(painel)`) — navegar entre
  módulos não perde mais o menu. Nome do produto corrigido de "ConnectionCyberSO" para
  **ConnectionCyber** em todo o painel, com a identidade visual oficial aplicada ("Connection"
  em vermelho `#E01F27`, "Cyber" em verde `#2C9C48`, ícone oficial). Testado com um sexto
  usuário real de staging.

## Documentação do projeto

Cada documento abaixo existe em três formatos — `.md` (leitura), `.json` (estruturado) e
`.html` (visual) — todos com o mesmo conteúdo.

| Documento | Conteúdo |
|---|---|
| `docs/parecer-tecnico-arquitetura` | Decisões de arquitetura (multi-tenant, isolamento, roteiro de implantação) |
| `docs/auditoria-ecossistema-connectioncyberos` | Achados da auditoria de `bpo-system-web-os`, `food-service-os` e `cyber-varejo-os`, e o que já foi trazido para cá |
| `docs/tecnologia-seletor-idioma` | Como o seletor PT/EN do site foi implementado |
| `docs/metodologia-povoamento-tenant-cnpj-cnae` | Padrão de povoamento de tenant via CNPJ + cenário por CNAE, trazido da auditoria de `Downloads\BPO` |
| `docs/visao-longo-prazo-modulos` | Mapa de 104 módulos avaliado em `Downloads\connectionHMTL` — arquivado como referência de longo prazo, nada implementado |
| `docs/migracao-diagnostico-digital-cc-commerce-studio` | Como o módulo Diagnóstico Digital (IA) foi migrado de `cc-commerce-studio` (`J:\BK_connectioncyber`) para `apps/platform` |
| `docs/Connection Cyber Site.txt` | Briefing original — conteúdo institucional/copy (não gera `.md`/`.json`/`.html`, é o documento-fonte) |
| `docs/prompt geral.txt` | Briefing original — blueprint técnico enterprise (não gera `.md`/`.json`/`.html`, é o documento-fonte) |
