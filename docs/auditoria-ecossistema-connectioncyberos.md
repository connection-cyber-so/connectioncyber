# Auditoria multi-projeto do ecossistema ConnectionCyberOS — achados relevantes para implementação

> Origem: auditoria somente-leitura realizada em 2026-08-12 sobre `F:\Projetos\bpo`,
> `F:\Projetos\food`, `F:\Projetos\varejo`, `F:\Projetos\ZZ-TECNICAS GERAIS SITES` e
> `F:\Projetos\ZZZ-MATRI GUIA MESTRE MARCO ZERO`. Este documento formaliza os achados que têm
> ação clara — não repete a auditoria inteira (essa ficou registrada na conversa). Nada nas
> pastas auditadas foi alterado; o que está aqui é referência para decidir o que trazer para
> `connectioncyber`.

## Status desta auditoria

**Atualizado em 2026-08-13.** Os 6 padrões reutilizáveis listados abaixo já foram trazidos
para este repositório (ver commits `f7234f8` e `449d9b7`) — as caixas de seleção originais
foram marcadas como concluídas. A decisão de stack (Pages Router vs. App Router) segue em
aberto. Os 3 itens de segurança urgentes continuam fora deste repositório e sem ação (dependem
do Joaquim diretamente, em contas de outros projetos).

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

## Padrões trazidos para `connectioncyber` — todos implementados

Validados em código real de outro projeto do mesmo ecossistema, e já aplicados aqui:

1. **✅ Trigger de auto-provisionamento de perfil.** Implementado em
   `supabase/migrations/0003_bpo_patterns_auto_provisioning_and_hook.sql`
   (`handle_new_user()`, trigger `on_auth_user_created` em `auth.users`). Referência original:
   `handle_new_bpo_admin()` em
   `bpo-system-web-os/supabase/migrations/20260724163546_onboarding_trigger.sql`.
2. **🟡 RLS via Custom Access Token Hook (JWT claims) em vez de subquery.** Função
   `custom_access_token_hook()` criada em `0003_bpo_patterns_auto_provisioning_and_hook.sql` —
   **falta 1 passo manual**: ativar em Authentication → Hooks no Dashboard do Supabase
   (não existe comando de CLI para isso em projeto hospedado). Até lá, `current_tenant_id()`
   continua funcionando exatamente como antes (subquery), nada quebrou. Referência original:
   `bpo-system-web-os/supabase/migrations/20260724161539_jwt_hook_and_rls_nucleo.sql`.
3. **✅ Proteção de rota no middleware, não em componente client-side.** Implementado em
   `apps/site/src/middleware.ts` (com `@supabase/ssr`) — corrige a causa raiz do bug de
   `/membros` travado em "Verificando acesso…" encontrado na validação local desta sessão.
   Referência original: `middleware.ts` + `utils/supabase/middleware.ts` em `bpo-system-web-os`
   e `food-service-os-staging` (padrão idêntico nos dois).
4. **✅ Catálogo de módulos compartilhado + habilitação por cliente.** Implementado em
   `supabase/migrations/0004_module_catalog_and_tenant_themes.sql` (`module_catalog` +
   `tenant_modules`, ciclo `diagnosticado → proposto → ativo → suspenso → encerrado`), já com
   seed dos 4 módulos que a ConnectionCyber vende hoje, todos `ativo` para o tenant
   ConnectionCyber. Confirma a arquitetura já decidida (Opção A do Parecer Técnico #001).
   Referência original: `module_catalog` + `client_modules` em
   `bpo-system-web-os/supabase/migrations/20260724162515_module_aware_core.sql`.
5. **✅ Enriquecimento de cadastro via CNPJ.** Implementado e testado em
   `supabase/functions/lookup-cnpj/index.ts` — consulta a BrasilAPI e devolve razão social,
   CNAE, situação cadastral, município/UF a partir do CNPJ. Diferente da referência original,
   já exige o `anon key` por padrão (verificação de JWT ativa). Referência original:
   `bpo-system-web-os/supabase/functions/lookup-cnpj/index.ts`.
6. **✅ Identidade visual por tenant como tabela própria.** Implementado em
   `0004_module_catalog_and_tenant_themes.sql` (`tenant_themes`: cor primária/secundária, logo,
   fonte, por `tenant_id`). Referência original: `client_themes` em `bpo-system-web-os`.

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
