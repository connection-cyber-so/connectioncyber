# apps/platform — ConnectionCyberSO (painel interno)

> **Fase 1 do plano de ação concluída**: esqueleto publicável + login funcionando. Ainda sem
> conteúdo de negócio — a lista de tenants é a Fase 2.

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
│  │  ├─ page.tsx           dashboard placeholder (protegido, force-dynamic)
│  │  └─ login/page.tsx     login de equipe (Client Component)
│  ├─ components/
│  │  └─ LogoutButton.tsx
│  ├─ lib/supabase/
│  │  ├─ client.ts          Supabase para Client Components (browser, chave anônima)
│  │  ├─ server.ts          Supabase para Server Components (lê sessão dos cookies)
│  │  └─ middleware.ts       updateSession() — padrão oficial @supabase/ssr para App Router
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

- `npm run build` limpo (App Router, `/` como rota dinâmica por depender de sessão).
- Rodando contra o Supabase de staging real: acesso a `/` sem sessão redireciona para `/login`;
  submeter credenciais inválidas retorna o erro real do Supabase Auth (`Invalid login
  credentials`), confirmando que client, middleware e o projeto de staging estão conectados de
  ponta a ponta.
- Testado em modo produção (`next start`) — o modo dev (`next dev`) tem HMR instável neste
  ambiente sandboxed, mesma observação já registrada para `apps/site`.

## Próximos passos (roteiro)

Ver o plano de ação completo na conversa com Joaquim — resumo:

1. ~~Esqueleto + login~~ (esta entrega)
2. Lista de tenants (Server Component lendo a tabela `tenants`) — os 10 clientes reais visíveis
   pela primeira vez fora do Supabase Table Editor
3. RBAC por módulo (padrão `user_module_access` do `bpo-system-web-os`)
4. CRUD de tenant + módulos, com `lookup-cnpj` embutido no formulário
5. Deploy: novo projeto Vercel apontando para esta pasta — ainda não criado, decisão pendente
   sobre Deployment Protection (recomendado: ligada por padrão, é painel interno, não site
   público)
