# connectioncyber — ConnectionCyberSO

**Tecnologia que traz conhecimento e gestão.**
Monorepo de produção (branch `main`) da ConnectionCyber — Assessoria e Treinamento Tecnológico.
Gabriel Batista de Assis Soares Coelho — MEI · CNPJ 13.348.881/0001-88.

Estrutura, decisões de arquitetura e o roteiro de implantação estão documentados no
**Parecer técnico #001** (artifact publicado na conversa com o Claude) — este README é só o
mapa rápido do repositório.

## Estrutura

```
connectioncyber/
├─ apps/
│  ├─ site/           site institucional — Next.js/TS (ver apps/site/README.md)
│  └─ platform/        ConnectionCyberSO (ERP/CRM/SaaS multi-tenant) — ainda não iniciado
├─ packages/
│  └─ core/            regras de negócio compartilhadas entre tenants — ainda não iniciado
├─ supabase/
│  └─ migrations/       schema único do projeto Supabase (multi-tenant via tenant_id + RLS)
├─ documentos/          briefings originais do projeto
└─ logo/                identidade visual
```

Ambiente de desenvolvimento (staging) é um **segundo clone** deste mesmo repositório, na
branch `staging`, em `F:\Projetos\connectioncyber-staging` — não uma pasta dentro deste
diretório. Ver Etapa 03 do roteiro.

## Decisões de arquitetura confirmadas

- **Multi-tenant**: 1 projeto Supabase único (`qfggetvashdxyuvlhihq`), isolamento por
  `tenant_id` + Row Level Security. Nenhum cliente novo gera projeto/repositório/pasta —
  vira uma linha na tabela `tenants`.
- **Staging**: clone irmão do repositório, não aninhado.
- **Site**: parte deste monorepo (`apps/site`), não um projeto separado.

## Status

- [x] `apps/site` construído e validado (`npm run build` limpo, 42 páginas).
- [x] Schema SQL inicial em `supabase/migrations/0001_init_schema.sql`.
- [ ] Repositório Git ainda não inicializado localmente.
- [ ] `supabase link` ainda não executado.
- [ ] Vercel ainda não conectado.
- [ ] `apps/platform` (ConnectionCyberSO) ainda não iniciado.
