# apps/platform — ConnectionCyberSO (painel interno)

> **Fase 1 concluída**: esqueleto + login. **4 módulos de negócio em produção**: Diagnóstico
> Digital (IA), Catálogo de Produtos e Ofertas (IA), Roteiro de Vídeo (IA) e Landing Pages —
> todos migrados de `cc-commerce-studio` (ver
> `docs/migracao-diagnostico-digital-cc-commerce-studio.md`). Landing Pages é o primeiro módulo
> com uma peça pública: gestão aqui, página publicada servida por `apps/site`.
> **Fase 6 concluída**: `/tenants` lista os clientes reais e os módulos habilitados de cada um —
> primeira vez fora do Supabase Table Editor.

Painel interno de gestão de tenants, módulos e clientes da ConnectionCyber — separado do site
institucional (`apps/site`). Só a equipe entra aqui; clientes finais usam `apps/site` (`/membros`).

## Decisão de arquitetura

**Next.js 14 + App Router**, diferente do `apps/site` (Pages Router). Decisão registrada e
justificada na conversa com Joaquim Coelho em 2026-08-15: Server Components fazem a consulta ao
Supabase direto no servidor (sem API route intermediária a esquecer de proteger), alinhado ao
modelo de isolamento por tenant já adotado no projeto, e compatível com o padrão App Router já
usado no resto do ecossistema auditado (`bpo-system-web-os`, `food-service-os`,
`cyber-varejo-os`).

`apps/site` continua em Pages Router — não há necessidade técnica de fazer os dois apps
convergirem, cada um tem seu próprio `package.json` e build.

## Estrutura

```
apps/platform/
├─ src/
│  ├─ app/
│  │  ├─ layout.tsx        layout raiz
│  │  ├─ globals.css       tokens de marca (copiados de apps/site/src/styles/theme.css) + shell
│  │  ├─ page.tsx           dashboard (protegido, force-dynamic, link para os módulos)
│  │  ├─ login/page.tsx     login de equipe (Client Component)
│  │  ├─ diagnostics/page.tsx  módulo Diagnóstico Digital (IA)
│  │  ├─ products/page.tsx     módulo Catálogo — cadastro de produtos
│  │  ├─ offers/page.tsx       módulo Catálogo — geração de oferta por IA
│  │  ├─ video-scripts/page.tsx  módulo Roteiro de Vídeo — geração por IA a partir de oferta
│  │  ├─ landing-pages/page.tsx  módulo Landing Pages — gestão (página pública é em apps/site)
│  │  └─ tenants/page.tsx      Fase 6 — lista de clientes + módulos habilitados (só leitura)
│  ├─ components/
│  │  └─ LogoutButton.tsx
│  ├─ features/
│  │  ├─ diagnostics/       actions.ts, service.ts, types.ts, validations.ts, components/
│  │  ├─ products/          idem — mpi_products
│  │  ├─ offers/             idem — mpi_offers (referencia products.id)
│  │  ├─ video-scripts/      idem — mpi_video_scripts (referencia offers.id)
│  │  ├─ landing-pages/       idem — mpi_landing_pages (referencia offers.id)
│  │  │                     (migrados de cc-commerce-studio — ver docs/migracao-diagnostico-*)
│  │  └─ tenants/             types.ts, service.ts, components/TenantCard.tsx — só leitura,
│  │                        RLS de public.tenants decide quem vê o quê (não o código)
│  ├─ lib/
│  │  ├─ tenant.ts          getCurrentTenantId()/requireCurrentTenantId() — deriva o tenant
│  │  │                      da SESSÃO, nunca de formulário/query string
│  │  └─ supabase/
│  │     ├─ client.ts       Supabase para Client Components (browser, chave anônima)
│  │     ├─ server.ts       Supabase para Server Components (lê sessão dos cookies)
│  │     └─ middleware.ts    updateSession() — padrão oficial @supabase/ssr para App Router
│  ├─ middleware.ts          protege tudo exceto /login
│  └─ config/env.ts
├─ .env.local.example
└─ package.json
```

## Modelo de segurança

Mesma camada de isolamento do resto do projeto: o servidor deriva o usuário da sessão (cookies
via `@supabase/ssr`), nunca de dado enviado pelo cliente. `middleware.ts` usa
`supabase.auth.getUser()` (não `getSession()`) — valida o JWT contra o servidor do Supabase a
cada request, em vez de só confiar no cookie.

## Rodando localmente

```bash
cd apps/platform
npm install
cp .env.local.example .env.local
# preencha com as chaves do Supabase de STAGING (ozvylnaipubrmaadikvk) — nunca produção
npm run dev   # porta 3001 (apps/site usa a 3000)
```

## Validado em 2026-08-15

- `npm run build` limpo (App Router, `/`, `/diagnostics`, `/products`, `/offers`,
  `/video-scripts`, `/landing-pages` como rotas dinâmicas por dependerem de sessão).
- Rodando contra o Supabase de staging real: acesso sem sessão redireciona para `/login`;
  submeter credenciais inválidas retorna o erro real do Supabase Auth (`Invalid login
  credentials`), confirmando que client, middleware e o projeto de staging estão conectados de
  ponta a ponta.
- **Diagnóstico Digital testado com usuário real de staging** (criado e apagado só para o
  teste): criar diagnóstico grava de verdade em `mpi_diagnostics` com `tenant_id` derivado da
  sessão, RLS valida, tela atualiza; editar título funciona pela UI.
- **Catálogo de Produtos e Ofertas testado com um segundo usuário real de staging**: cadastrar
  produto grava em `mpi_products`; o formulário de oferta lista o produto automaticamente;
  "Gerar copy com IA" busca o produto sob RLS da própria sessão e referencia o nome certo;
  criar oferta grava em `mpi_offers` com `product_id` correto.
- **Roteiro de Vídeo testado com um terceiro usuário real de staging**: encadeando produto →
  oferta → roteiro, `/video-scripts` pré-seleciona a oferta recém-criada, "Gerar roteiro com
  IA" busca oferta + produto sob RLS da sessão, criar roteiro grava em `mpi_video_scripts` com
  `offer_id` correto.
- **Landing Pages testado com um quarto usuário real de staging, ponta a ponta até o público**:
  criar como rascunho e publicar funcionam pela UI; a página publicada foi acessada em
  `apps/site` (`/lp/<slug>`), em processo separado, **sem sessão nenhuma** — carregou o
  conteúdo real; despublicar (mudando `status` para `draft`) faz a mesma URL devolver `404`,
  confirmando que a RLS pública depende só do `status`. Detalhe completo em
  `docs/migracao-diagnostico-digital-cc-commerce-studio.md`.
- **`/tenants` testado com um quinto usuário real de staging, com papel de equipe** (`admin` em
  `user_roles` — criado e removido só para o teste): a página mostrou o tenant e os 4 módulos
  seed como `ativo`, confirmando que `is_platform_staff()` libera a visão cross-tenant. Um
  usuário sem esse papel só veria a própria linha — comportamento herdado da RLS já validada em
  `0002`/`0004`, não retestado à parte por já estar coberto.
- Testado em modo produção (`next start`) — o modo dev (`next dev`) tem HMR instável neste
  ambiente sandboxed, mesma observação já registrada para `apps/site`.

## Próximos passos (roteiro)

Ver o plano de ação completo na conversa com Joaquim — resumo:

1. ~~Esqueleto + login~~ (concluído)
2. ~~Diagnóstico Digital (migrado de `cc-commerce-studio`)~~ (concluído)
3. ~~Catálogo de Produtos e Ofertas (Products + Offer Engine, migrados de `cc-commerce-studio`)~~ (concluído)
4. ~~Roteiro de Vídeo (Video Script Engine, migrado de `cc-commerce-studio`)~~ (concluído)
5. ~~Landing Pages (gestão aqui, página pública em `apps/site`, migrado de `cc-commerce-studio`)~~ (concluído)
6. ~~Lista de tenants (`/tenants`, só leitura, RLS decide quem vê o quê)~~ (concluído)
7. RBAC por módulo (padrão `user_module_access` do `bpo-system-web-os`)
8. CRUD de tenant + módulos, com `lookup-cnpj` embutido no formulário
9. Migrar os últimos 2 motores do `cc-commerce-studio` — Brands (FK opcional, sem urgência);
   Workspace genérico não se aplica mais (substituído pelo modelo de tenant)
10. Deploy: novo projeto Vercel apontando para esta pasta — ainda não criado, decisão pendente
    sobre Deployment Protection (recomendado: ligada por padrão, é painel interno, não site
    público)

## Login próprio de Joaquim — resolvido em 2026-08-15

Conta pessoal criada pelo próprio Joaquim (Supabase Dashboard → Authentication → Users → Add
user, ação exclusiva dele) em **produção** (`qfggetvashdxyuvlhihq`) e em **staging**
(`ozvylnaipubrmaadikvk`), mesmo e-mail (`admin@connectioncyber.com.br`), senhas diferentes por
ambiente. Em ambos os projetos: linha em `public.users` confirmada (auto-provisionada pelo
trigger `handle_new_user`, ver `0003_bpo_patterns_auto_provisioning_and_hook.sql`) e papel
`admin` atribuído em `user_roles` — feito via script pontual com a `service_role` key, apagada
do disco logo depois de rodar (dado, não credencial). `/tenants` já testado ao vivo com um
usuário descartável mostrando o tenant ConnectionCyber e os 4 módulos seed; falta só a
confirmação de Joaquim rodando `npm run build && npm run start` e entrando com a própria conta
de staging.
