# Auditoria multi-projeto do ecossistema ConnectionCyberOS — achados relevantes para implementação

> Origem: auditoria somente-leitura realizada em 2026-08-12 sobre `F:\Projetos\bpo`,
> `F:\Projetos\food`, `F:\Projetos\varejo`, `F:\Projetos\ZZ-TECNICAS GERAIS SITES` e
> `F:\Projetos\ZZZ-MATRI GUIA MESTRE MARCO ZERO`. Este documento formaliza os achados que têm
> ação clara — não repete a auditoria inteira (essa ficou registrada na conversa). Nada nas
> pastas auditadas foi alterado; o que está aqui é referência para decidir o que trazer para
> `connectioncyber`.

## Ação imediata — segurança (fora deste repositório, mas urgente)

- [ ] **Revogar/rotacionar os segredos expostos em texto puro** em
  `F:\Projetos\varejo\CYBER VAREJO OS documentação.docx` (tokens do GitHub e uma chave
  `service_role` completa do Supabase). Não estão neste repositório, mas são credenciais reais
  vivas guardadas sem proteção.
- [ ] Revisar o endpoint `onboard-bpo` (Edge Function) em `bpo-system-web-os` — hoje é público,
  sem autenticação, sem rate limit, e usa a `service_role key` para criar tenants e usuários
  admin. Se for reutilizado como referência de onboarding do ConnectionCyberSO, **não copiar
  esse padrão sem adicionar autenticação/limite de uso**.
- [ ] Ao portar qualquer `GRANT` de `bpo-system-web-os` para `connectioncyber`, **não usar
  `GRANT ALL ... TO anon`** — escopar ao mínimo necessário por tabela.

## Padrões prontos para adotar no `apps/platform` (ConnectionCyberSO)

Já validados em código real de outro projeto do mesmo ecossistema — não são teoria:

1. **Trigger de auto-provisionamento de perfil.** `connectioncyber` hoje não cria
   automaticamente uma linha em `public.users` quando alguém se cadastra pelo Supabase Auth —
   é um gap real. Referência: `handle_new_bpo_admin()` em
   `bpo-system-web-os/supabase/migrations/20260724163546_onboarding_trigger.sql` (trigger em
   `auth.users`, lê `bpo_id`/`role` de `raw_user_meta_data`).
2. **RLS via Custom Access Token Hook (JWT claims) em vez de subquery.** O `current_tenant_id()`
   atual do `connectioncyber` faz `select ... from users where id = auth.uid()` a cada checagem
   de RLS. Referência superior: `custom_access_token_hook()` em
   `bpo-system-web-os/supabase/migrations/20260724161539_jwt_hook_and_rls_nucleo.sql`, que
   grava `tenant_id`/`role` direto no `app_metadata` do JWT na emissão do token — RLS lê do
   token, sem subquery.
3. **Proteção de rota no middleware, não em componente client-side.** Foi a causa raiz do bug
   de `/membros` travado em "Verificando acesso…" corrigido nesta sessão. Referência:
   `middleware.ts` + `utils/supabase/middleware.ts` em `bpo-system-web-os` e
   `food-service-os-staging` (padrão idêntico nos dois).
4. **Catálogo de módulos compartilhado + habilitação por cliente.** Confirma a arquitetura já
   decidida para o ConnectionCyberSO (Opção A do Parecer Técnico #001): uma rotina/módulo entra
   uma vez no catálogo, cada tenant liga/desliga individualmente. Referência: `module_catalog` +
   `client_modules` (com ciclo `diagnosticado → proposto → ativo → suspenso → encerrado`) em
   `bpo-system-web-os/supabase/migrations/20260724162515_module_aware_core.sql`.
5. **Enriquecimento de cadastro via CNPJ.** Edge Function que consulta a BrasilAPI e preenche
   razão social, CNAE, situação cadastral, município/UF automaticamente a partir do CNPJ.
   Referência: `bpo-system-web-os/supabase/functions/lookup-cnpj/index.ts`. Direto reaproveitável
   para o cadastro de tenant/cliente do ConnectionCyberSO.
6. **Identidade visual por tenant como tabela própria.** `client_themes` (cor primária/secundária,
   logo, fonte, por `client_id`) em `bpo-system-web-os` — modelo de referência para quando
   `tenants` precisar de branding além do campo `dominio` que já existe.

## Decisão de arquitetura pendente — stack canônica

O `HANDOFF_FOODSERVICE_OS.docx` (projeto FoodOS) cita um `ECOSISTEMA_PADRAO.md` como stack
obrigatória de todo o ecossistema: **Next.js com App Router, TypeScript strict, Tailwind CSS v4,
`@supabase/ssr`**. Esse arquivo não estava nas pastas auditadas — só a referência a ele. O que
construímos para `connectioncyber` usa **Next.js 14 com Pages Router, sem Tailwind**, o que
diverge do padrão citado.

**Isso não foi decidido nesta auditoria — só registrado.** Antes de investir mais em
`apps/platform`, vale localizar o `ECOSISTEMA_PADRAO.md` (provavelmente em
`F:\Projetos\connection-cyber-os`, pasta que existe no disco mas não fez parte do escopo desta
auditoria) e decidir explicitamente: manter Pages Router no `connectioncyber` ou migrar para
App Router antes que `apps/platform` cresça e a migração fique mais cara.

## Achados sem ação (registro, não bloqueiam nada)

- `ZZZ-MATRI GUIA MESTRE MARCO ZERO` duplica parte do conteúdo de `ZZ-TECNICAS GERAIS SITES`
  (confirmado por diff idêntico em pelo menos um arquivo). Vale decidir qual pasta é a
  referência única, quando houver tempo — não é urgente.
- Cliente piloto real do FoodOS: **Natural da Terra**, 4 unidades em Piracicaba/SP — contexto de
  negócio real encontrado no handoff, útil para quando o módulo de food entrar em pauta.
- Arquitetura de PDV offline planejada em `cyber-varejo-os` (Electron + SQLite local +
  impressora térmica) — zero código ainda, mas relevante se algum tenant de varejo físico do
  ConnectionCyberSO precisar de caixa que funcione sem internet.

## Referência completa

A auditoria integral (todas as pastas, arquitetura, achados de segurança detalhados, tabela de
módulos avançados comparados) está registrada na conversa desta sessão — este documento é o
resumo acionável, não substitui a leitura completa se for preciso revisitar algum detalhe.
