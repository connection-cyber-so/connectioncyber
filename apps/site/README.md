# apps/site — Site Corporativo ConnectionCyber

> **Tecnologia que traz conhecimento e gestão.**
> Site institucional, portal de pagamentos, área de membros e mapa arquitetural
> enterprise da **ConnectionCyber — Assessoria e Treinamento Tecnológico**.

Este app foi gerado a partir da unificação de dois documentos de briefing
(`docs/Connection Cyber Site.txt` — conteúdo institucional/copy — e
`docs/prompt geral.txt` — blueprint técnico enterprise) em um único
projeto Next.js executável, construído de ponta a ponta.

Faz parte do monorepo `connectioncyber` (ver `Parecer técnico #001` para o
racional da estrutura): vive em `apps/site`, ao lado de `apps/platform`
(ConnectionCyberSO, ainda não iniciado) e `packages/core` (regras de negócio
compartilhadas). O schema Supabase é único para todo o monorepo e vive na
raiz, em `../../supabase/migrations` — não mais dentro deste app.

---

## ✅ O que já está pronto e funcionando

- **Site institucional completo** (Next.js 14 + TypeScript + Pages Router):
  Home, Sobre, Serviços, Treinamentos/Cursos, Produtos, Área de Clientes,
  Contato, Sistema (mapa enterprise), Checkout, retorno de pagamento.
- **Identidade visual oficial** — logo real (`public/logo.png`, a partir de
  `logo/logosf.png`) e paleta de marca oficial em `src/styles/theme.css`
  (`#F6851F`/`#F8961D`/`#E01F27`/`#CA2127`/`#2C9C48`/`#4CB853`/`#28A992`/`#1E9680`).
- **i18n PT-BR / EN-US** — `src/i18n/*.json` + `LanguageContext` +
  `LanguageSwitcher` no header (Context API do React, sem biblioteca externa
  — ver `../../docs/tecnologia-seletor-idioma.md`). O i18n nativo do Next.js
  foi **removido** de `next.config.js`: duplicava as páginas por locale sem
  que nada navegasse para as URLs prefixadas, e foi a causa mais provável de
  um `NOT_FOUND` na borda da Vercel após o deploy.
- **Página `/login`** funcional (`src/pages/login/index.tsx`) e **middleware
  de proteção de rota** (`src/middleware.ts`, via `@supabase/ssr`) — protege
  `/membros` no servidor, antes de qualquer HTML ser enviado. Substitui a
  dependência exclusiva do guard client-side (`ProtectedRoute.tsx`), que
  travava em "Verificando acesso…" quando o Supabase não estava configurado.
- **Header, Footer, Layout, rotas protegidas, botões flutuantes de redes
  sociais** (WhatsApp, Instagram, Facebook, LinkedIn, YouTube, TikTok, ícones
  SVG reais — antes eram letras) com tracking best-effort (gtag + webhook
  n8n). Header: botão "Fale Conosco" trocado por **"Fazer Login"**
  (`/login`), mesma cor de fundo, borda `1.5px solid #F6851F`.
- **Padrão de borda (2026-08-15)**: todos os botões (`.btn` — primário,
  outline, outline-dark, em Home/Serviços/Treinamentos/Contato) e os ícones
  flutuantes de rede social usam `1.5px solid #F6851F` (laranja); cards
  (`.card`), campos de formulário (`/login`, `/contato`) e a caixa do
  Sistema Visual Enterprise (`.enterprise-frame`) usam `1px solid #28A992`
  (verde-azulado da marca).
- **Sistema Visual Enterprise — retoques (2026-08-15)**: nome corrigido de
  "CONNECTIONCYBER" para **ConnectionCyber** (com o ícone oficial, não mais
  um ponto colorido) no painel lateral; os 6 ícones de modo (emoji) viraram
  SVGs técnicos (prédio, termômetro, átomo, órbita, chip, escudo); nova
  troca de estilo de mapa **fora do iframe**, na própria página `/sistema`
  (`postMessage` same-origin — `connectioncyber:set-mode` — troca o modo ao
  vivo sem recarregar o iframe nem perder zoom/posição).
- **Área de Clientes** (`/clientes`) com componente pronto para os 15 clientes
  com contrato de longa data — **dados reais pendentes**, ver seção
  "Ações pendentes" abaixo.
- **Autenticação e RBAC** — `src/lib/auth.ts` (Supabase Auth: login, cadastro,
  logout, recuperação de senha, papéis admin/instrutor/aluno/cliente/
  suporte/tecnico/visitante) + `ProtectedRoute.tsx`.
- **Área de Membros estilo Netflix** (`/membros`) — estrutura de trilhas e
  progresso pronta, protegida por login; dados reais dependem do schema.
- **Pagamentos Mercado Pago** — `src/lib/payments.ts` +
  `/api/payments/create-preference` + `/api/payments/webhook` +
  `/checkout` + `/pagamento/sucesso` + `/pagamento/erro`.
- **Formulário de contato funcional** — `/api/contato` grava em
  `contact_messages` (Supabase) e dispara webhook n8n, se configurados.
- **Schema completo Supabase/PostgreSQL** — `../../supabase/migrations/` (raiz do monorepo),
  4 migrations aplicadas no projeto real (`qfggetvashdxyuvlhihq`):
  usuários, papéis (RBAC), cursos, matrículas, trilhas, quizzes, provas/simulados, produtos,
  pedidos, pagamentos, mídia, CMS, analytics, módulo de acesso remoto para clientes;
  `tenants` + `tenant_id` + RLS (multi-tenant); trigger de auto-provisionamento
  (`auth.users` → `public.users`) e `custom_access_token_hook` (função pronta — falta 1 clique
  manual no Dashboard para ativar); `module_catalog` + `tenant_modules` (catálogo de módulos
  compartilhado, habilitação por tenant) + `tenant_themes` (branding por tenant).
- **Edge Function `lookup-cnpj`** (`../../supabase/functions/lookup-cnpj`) — consulta a
  BrasilAPI por CNPJ, implantada e testada.
- **Sistema Visual Enterprise** — `public/enterprise-system.html`
  (HTML+CSS+JS puro, sem dependências externas), embutido em `/sistema` via
  `<iframe>`. Mapa com 22 nós (7 clusters + 15 módulos) e 33 conexões,
  com:
  - física real (repulsão, molas, colisão, damping)
  - modo Órbita (módulos orbitando clusters hub: Blueprint, IA, Segurança,
    Cursos, Sistemas)
  - modo Heatmap (4 níveis de calor, com legenda)
  - modo IA (auto-reorganização simulada, pulso periódico)
  - modo Segurança (realça nós/arestas críticos, esmaece o restante)
  - zoom (scroll) + pan (arraste) + seleção de nó com painel de detalhes
  - painel lateral com legenda de clusters, métricas de governança e troca
    de modo
- **`npm run build` validado** — 17 rotas (14 páginas + 3 API routes), 0 erros de
  tipo/compilação (contagem caiu de 42 para o número real de rotas únicas
  depois da remoção do i18n nativo do Next.js, que duplicava tudo por locale).
- **Deploy Vercel validado** — produção no ar; dois problemas reais foram
  encontrados e corrigidos no processo: Deployment Protection bloqueando o
  domínio público (desativada no painel), e o `NOT_FOUND` do i18n citado acima.

---

## 🗂 Estrutura de pastas (monorepo)

```
F:\Projetos\connectioncyber                 ← produção · branch main
├─ logo/                        (logo oficial — logosf.png)
├─ docs/                        (único local de documentação — briefings originais +
│                                 documentos técnicos JSON+MD+HTML; só existe em main)
├─ supabase/
│  ├─ migrations/                (0001 a 0004, schema único, todo o monorepo)
│  └─ functions/lookup-cnpj/     (Edge Function — implantada)
├─ packages/
│  └─ core/                     (regras de negócio compartilhadas — ainda não iniciado)
└─ apps/
   ├─ platform/                 (ConnectionCyberSO — painel interno, ver apps/platform/README.md)
   └─ site/                     ← projeto Next.js (este README)
      ├─ src/
      │  ├─ pages/              (rotas: index, sobre, servicos, cursos,
      │  │                       produtos, clientes, membros, login, sistema,
      │  │                       contato, checkout, pagamento/*, api/*,
      │  │                       lp/[slug] — landing page pública, sem login,
      │  │                       gerenciada em apps/platform)
      │  ├─ components/         (Header, Footer, Layout, LanguageSwitcher,
      │  │                       ProtectedRoute, FloatingSocialButtons,
      │  │                       ServiceCard, ClientCard)
      │  ├─ context/LanguageContext.tsx
      │  ├─ lib/                (supabaseClient, auth, payments)
      │  ├─ config/             (env, routes, clients)
      │  ├─ i18n/               (pt-BR.json, en-US.json)
      │  ├─ styles/             (globals.css, theme.css)
      │  └─ middleware.ts       (protege /membros no servidor)
      ├─ public/enterprise-system.html, logo.png
      ├─ package.json / tsconfig.json / next.config.js
      └─ .env.local.example

F:\Projetos\connectioncyber-staging          ← staging · branch staging (2º clone, ver Etapa 03)
```

---

## ▶️ Como rodar localmente

```bash
cd F:/Projetos/connectioncyber/apps/site
npm install
cp .env.local.example .env.local
npm run dev
```

Abra `http://localhost:3000`. O site funciona **sem** nenhuma credencial
preenchida (usa dados de demonstração nas páginas de Cursos/Produtos/
Clientes); os recursos que dependem de serviços externos ficam inativos
até as chaves serem configuradas (ver próxima seção).

---

## 🔑 Ações pendentes (exigem decisão/credenciais do Joaquim)

Estas são as únicas partes que **não podem ser inventadas** — precisam de
dados reais ou de uma conta sua em cada serviço:

1. ~~**Supabase**~~ ✅ feito — projeto linkado, 4 migrations aplicadas, Edge Function no ar.
   Falta só ativar o `custom_access_token_hook` em Authentication → Hooks no Dashboard
   (1 clique, não dá pra fazer por CLI em projeto hospedado).
2. **Mercado Pago** — conta de vendedor + `MERCADOPAGO_ACCESS_TOKEN` +
   `NEXT_PUBLIC_MERCADOPAGO_PUBLIC_KEY` (produção ou sandbox).
3. **Domínio `connectioncyber.com.br`** — apontar DNS para a Vercel.
4. ~~**Vercel**~~ ✅ feito — repositório conectado, deploy de produção validado.
5. **Carteira de 15 clientes** — `src/config/clients.ts` está com
   placeholders genéricos (`Cliente Corporativo 1..15`) porque os nomes
   reais das empresas não estavam nos documentos de briefing. Substitua
   pelos dados reais (nome, logo, segmento, serviços, anos de parceria).
6. **Números de contato reais** — `src/config/routes.ts` (`socialLinks`)
   tem um número de WhatsApp placeholder (`5519000000000`) e links de redes
   sociais genéricos — trocar pelos reais.
7. **n8n** — URL da instância (`N8N_BASE_URL`) e token, se/quando a
   automação for ativada.
8. **GitHub** — conta `connection-cyber-so` está temporariamente suspensa;
   desbloqueio já solicitado. `main` está com commits locais aguardando push.

Nenhuma dessas pendências bloqueia o funcionamento do site — todas têm
fallback seguro (dados de demonstração, tracking silenciosamente
desativado, etc.).

---

## 🧭 Roadmap dos módulos avançados (prompt geral, seções 9–17)

O briefing técnico pede um ecossistema muito amplo (automação n8n completa,
reconhecimento facial, upload automático de fotos, gamificação, quizzes com
editor administrativo, simulados com correção automática, CMS completo,
módulo de acesso remoto para manutenção de clientes, e clusters verticais de
Varejo e Food). O **schema de banco já contempla todas essas tabelas** e as
páginas centrais (Membros, Sistema, Clientes) já têm a estrutura de UI e os
pontos de extensão prontos. O que ainda depende de implementação incremental
(cada um é um projeto por si só e requer decisões de produto/UX):

| Módulo | Status | Observação |
|---|---|---|
| Automação n8n (matrículas, certificados, backups, notificações) | 🟡 Webhooks previstos no código (`env.n8n`), workflows n8n em si ficam de fora deste repo | Criar os workflows no n8n e apontar `N8N_BASE_URL` |
| Reconhecimento facial (login, provas, certificados) | ⬜ Não iniciado | Requer escolha de provedor (Face API / AWS Rekognition / Google Vision) e política de privacidade/LGPD antes de codar |
| Quizzes/simulados/provas — motor completo + editor admin | 🟡 Schema pronto (`quizzes`, `exam_*`) | Falta painel administrativo de criação/edição |
| Gamificação (pontos, medalhas, ranking) | ⬜ Não iniciado | Depende do motor de quizzes/provas estar operando primeiro |
| CMS administrativo | 🟡 Tabela `cms_content` pronta | Falta painel de edição |
| Analytics/observabilidade/backup automatizado | 🟡 Tabela `analytics_events` pronta | Integrar com Vercel Analytics/Supabase Log Drains |
| Painel de Acesso Remoto (`/clientes/[id]/...`) | 🟡 Tabelas `remote_*` prontas | Falta a interface administrativa |
| Clusters Varejo / Food | ⬜ Comentado no SQL | Ativar quando esses segmentos forem contratados |
| CI/CD (GitHub Actions) | ⬜ Não iniciado | Depende do repositório estar no GitHub |
| Feature flags | ⬜ Não iniciado | Pode nascer como linhas em `system_settings` |

Legenda: ✅ pronto · 🟡 base pronta, falta camada administrativa/integração ·
⬜ não iniciado.

---

## 🛡 Segurança

- `npm audit` está limpo de vulnerabilidades **críticas** (Next.js atualizado
  para `14.2.35`, patch mais recente da série 14). Restam alertas
  **moderados/altos em dependências de desenvolvimento** (`glob` via
  `eslint-config-next`, `postcss` via toolchain de build, `uuid` via SDK do
  Mercado Pago 2.x) — nenhuma delas roda em runtime exposto a usuários finais;
  revisar com `npm audit` periodicamente e considerar migrar para
  `mercadopago@3.x` (breaking change na API) quando houver tempo dedicado a
  testar a nova assinatura do SDK.
- Chaves privadas (`SUPABASE_SERVICE_ROLE_KEY`, `MERCADOPAGO_ACCESS_TOKEN`)
  só são lidas em código server-side (`getSupabaseAdminClient`, `lib/payments.ts`)
  — nunca expostas ao browser.
- RLS habilitado nas tabelas com dado pessoal/financeiro; acesso
  administrativo passa pela service role em API routes.

---

## 📌 Resumo executivo

Os dois documentos de briefing foram unificados assim:
- **`Connection Cyber Site.txt`** definiu o *conteúdo* institucional (missão,
  visão, valores, textos de cada página, área de clientes) → virou o
  copy real das páginas (`src/i18n/pt-BR.json` e as próprias páginas).
- **`prompt geral.txt`** definiu a *arquitetura técnica* (stack, banco de
  dados, pagamentos, sistema visual enterprise, módulos avançados) → virou a
  estrutura de código, o schema SQL e o sistema visual.

O resultado é um projeto único, coerente, que builda sem erros e roda local
imediatamente — com um caminho claro e documentado para os módulos que
exigem credenciais reais ou decisões de produto que só você pode tomar.
