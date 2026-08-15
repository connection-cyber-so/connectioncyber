# apps/platform — ConnectionCyberSO (painel interno)

> **Fase 1 concluída**: esqueleto + login. **2 módulos de negócio em produção**: Diagnóstico
> Digital (IA) e Catálogo de Produtos e Ofertas (IA) — ambos migrados de `cc-commerce-studio`
> (ver `docs/migracao-diagnostico-digital-cc-commerce-studio.md`). A lista de tenants (Fase 3)
> ainda não existe.

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
│  │  └─ offers/page.tsx       módulo Catálogo — geração de oferta por IA
│  ├─ components/
│  │  └─ LogoutButton.tsx
│  ├─ features/
│  │  ├─ diagnostics/       actions.ts, service.ts, types.ts, validations.ts, components/
│  │  ├─ products/          idem — mpi_products
│  │  └─ offers/             idem — mpi_offers (referencia products.id)
│  │                        (migrados de cc-commerce-studio — ver docs/migracao-diagnostico-*)
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

- `npm run build` limpo (App Router, `/`, `/diagnostics`, `/products`, `/offers` como rotas
  dinâmicas por dependerem de sessão).
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
  criar oferta grava em `mpi_offers` com `product_id` correto. Detalhe completo em
  `docs/migracao-diagnostico-digital-cc-commerce-studio.md`.
- Testado em modo produção (`next start`) — o modo dev (`next dev`) tem HMR instável neste
  ambiente sandboxed, mesma observação já registrada para `apps/site`.

## Próximos passos (roteiro)

Ver o plano de ação completo na conversa com Joaquim — resumo:

1. ~~Esqueleto + login~~ (concluído)
2. ~~Diagnóstico Digital (migrado de `cc-commerce-studio`)~~ (concluído)
3. ~~Catálogo de Produtos e Ofertas (Products + Offer Engine, migrados de `cc-commerce-studio`)~~ (concluído)
4. Lista de tenants (Server Component lendo a tabela `tenants`) — os 10 clientes reais visíveis
   pela primeira vez fora do Supabase Table Editor
5. RBAC por módulo (padrão `user_module_access` do `bpo-system-web-os`)
6. CRUD de tenant + módulos, com `lookup-cnpj` embutido no formulário
7. Migrar os outros 5 motores do `cc-commerce-studio` (Landing Pages, Video Script Engine,
   Brands, Workspace genérico), um de cada vez — Landing Pages e Video Script Engine dependem
   de `offers` (já disponível)
8. Deploy: novo projeto Vercel apontando para esta pasta — ainda não criado, decisão pendente
   sobre Deployment Protection (recomendado: ligada por padrão, é painel interno, não site
   público)
