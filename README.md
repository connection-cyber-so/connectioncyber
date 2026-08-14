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
│  └─ platform/        ConnectionCyberSO (ERP/CRM/SaaS multi-tenant) — ainda não iniciado
├─ packages/
│  └─ core/            regras de negócio compartilhadas entre tenants — ainda não iniciado
├─ supabase/
│  ├─ migrations/       schema único do projeto Supabase (multi-tenant via tenant_id + RLS)
│  └─ functions/        Edge Functions (lookup-cnpj)
├─ docs/                documentação técnica do projeto (este índice, parecer, auditoria)
├─ documentos/          briefings originais do projeto
└─ logo/                identidade visual (logosf.png é o arquivo oficial)
```

Ambiente de desenvolvimento (staging) é um **segundo clone** deste mesmo repositório, na
branch `staging`, em `F:\Projetos\connectioncyber-staging` — não uma pasta dentro deste
diretório.

## Decisões de arquitetura confirmadas

- **Multi-tenant**: 1 projeto Supabase único (`qfggetvashdxyuvlhihq`), isolamento por
  `tenant_id` + Row Level Security. Nenhum cliente novo gera projeto/repositório/pasta —
  vira uma linha na tabela `tenants`.
- **Staging**: clone irmão do repositório, não aninhado.
- **Site**: parte deste monorepo (`apps/site`), não um projeto separado.
- **Pendente de decisão**: divergência entre a stack canônica documentada no ecossistema
  (Next.js App Router + Tailwind) e a stack atual deste repositório (Next.js 14 Pages Router,
  CSS custom) — ver `docs/auditoria-ecossistema-connectioncyberos.md`.

## Status

- [x] `apps/site` construído e validado (`npm run build` limpo).
- [x] Logo oficial e paleta de marca corrigidas (`#F6851F`/`#F8961D`/`#E01F27`/`#CA2127`/
  `#2C9C48`/`#4CB853`/`#28A992`/`#1E9680`).
- [x] Página `/login` e middleware de proteção de rota (`apps/site/src/middleware.ts`) — corrige
  o hang de `/membros` encontrado na validação local.
- [x] Repositório Git inicializado, branches `main` e `staging` publicadas no GitHub
  (`connection-cyber-so/connectioncyber`).
- [x] `supabase link` executado — projeto `connectioncyber` (`qfggetvashdxyuvlhihq`) vinculado.
- [x] Schema aplicado no projeto real: `0001_init_schema`, `0002_multi_tenant`,
  `0003_bpo_patterns_auto_provisioning_and_hook`, `0004_module_catalog_and_tenant_themes`.
- [x] Edge Function `lookup-cnpj` implantada e testada (consulta BrasilAPI por CNPJ).
- [x] Vercel conectado — deploy de produção validado.
- [ ] **Pendente (1 clique manual no Dashboard)**: ativar `custom_access_token_hook` em
  Authentication → Hooks — https://supabase.com/dashboard/project/qfggetvashdxyuvlhihq/auth/hooks
- [ ] `apps/platform` (ConnectionCyberSO) ainda não iniciado.
- ⚠️ **GitHub temporariamente suspenso** (conta `connection-cyber-so`, desbloqueio já
  solicitado) — commits seguem sendo feitos localmente; `main` está 5 commits à frente de
  `origin/main` aguardando push.

## Documentação do projeto

Cada documento abaixo existe em três formatos — `.md` (leitura), `.json` (estruturado) e
`.html` (visual) — todos com o mesmo conteúdo.

| Documento | Conteúdo |
|---|---|
| `docs/parecer-tecnico-arquitetura` | Decisões de arquitetura (multi-tenant, isolamento, roteiro de implantação) |
| `docs/auditoria-ecossistema-connectioncyberos` | Achados da auditoria de `bpo-system-web-os`, `food-service-os` e `cyber-varejo-os`, e o que já foi trazido para cá |
| `docs/tecnologia-seletor-idioma` | Como o seletor PT/EN do site foi implementado |
