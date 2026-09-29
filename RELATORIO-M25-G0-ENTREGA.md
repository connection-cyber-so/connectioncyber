# Relatório M25-G0 - Assinatura SaaS: entrega local e gate de staging

**Data:** 28/09/2026
**Executor:** automação (execução ponta a ponta autorizada pelo responsável)
**Ambientes:** local (stack Supabase + `apps/site`) e staging (`ozvylnaipubrmaadikvk`)
**Produção:** não alterada

## 1. O que foi entregue

| Artefato | Conteúdo |
|---|---|
| `supabase/migrations/0051_m25_saas_billing_subscriptions.sql` | 5 tabelas (`saas_plans`, `saas_plan_capabilities`, `saas_checkout_intents`, `saas_subscriptions`, `saas_billing_events`) com RLS; 6 RPCs service_role-only; seed do plano `padrao` (19900 centavos, 13 capabilities) |
| `supabase/rollback/0051_...rollback.sql` | Rollback completo (não dropa extensões nem objetos de outras migrations) |
| `supabase/tests/0051_....test.sql` | Estrutural — **plan(38)** |
| `supabase/tests/0051_....adversarial.test.sql` | Adversarial — **plan(28)** (claims trocadas, allow-list, idempotência, replay com correção, provisionamento, capabilities suspensas, eventos) |
| `supabase/preflight/0051_..._preflight.sql` | Read-only; recusa pré e pós-aplicação; exige 0050 + contrato 0034 |
| `supabase/validation/build-0051-transaction.mjs` + `0051_transaction.generated.sql` | Transação única migration+testes com **ROLLBACK** (66 asserções) |
| `supabase/verification/0051_post_apply.sql` | Auditoria pós-aplicação com marcador `M25_POST_APPLY_OK` |
| `supabase/validation/run-0051-remote.ps1` | Runner remoto `validate`/`apply`/`verify` |
| `apps/site/src/pages/planos/index.tsx` | Tela `/planos`: catálogo (RLS anônima) + formulário da empresa + assinar |
| `apps/site/src/pages/api/payments/create-subscription.ts` | POST: sessão → intenção → Preapproval MP → bind → `checkoutUrl` (409 se assinatura ativa) |
| `apps/site/src/lib/subscriptionValidation.ts` | Validação pura do cadastro (espelha a RPC) |
| `apps/site/src/lib/subscriptionLifecycle.ts` | Decisão + orquestração das transições do webhook (injeção de admin) |
| `apps/site/src/lib/webhookRouting.ts` | Classificação da notificação (assinatura × pedido) |
| `apps/site/src/lib/payments.ts` | `createSubscriptionPreapproval` e `getPreapprovalStatus` (SDK `PreApproval`) |
| `apps/site/src/pages/api/payments/webhook.ts` | Bifurcado por tópico; fluxo de pedidos inalterado |
| `apps/site/tests/subscription-*.test.mjs`, `webhook-routing.test.mjs` | `node:test` — 12 asserções novas |

## 2. Evidências de execução

### 2.1 Local

- Migration aplicada localmente (`psql` em `supabase_db_connectioncyber`,
  `ON_ERROR_STOP=1`) e re-aplicada após ajustes (IE obrigatória para o contrato 0034;
  replay com payload corrigido).
- Estrutural **38/38**; adversarial **28/28** (após corrigir: `has_table_privilege` não
  aceita `ALL`, `set local role` não é `select`, hook `handle_new_user` já cria
  `public.users`, ordem de avaliação em expressão única com RPC, IE obrigatória).
- Transação gerada local: marcador `M25_0051_TRANSACTION_66_OF_66_ROLLBACK` sem erros.
- Site: `tsc --noEmit` **0 erros**, `next lint` **sem avisos**, `node --test` **36/36**,
  `next build` **exit 0** (rota `/planos` + `/api/payments/create-subscription`).

### 2.2 Staging (runner `run-0051-remote.ps1`)

**Fase validate (sem escrita persistente):**

- Preflight `M25_PREFLIGHT_OK` (1/2) e re-execução pós-transação (2/2) = prova de resíduo zero.
- Transação **66/66** com marcador `M25_0051_TRANSACTION_66_OF_66_ROLLBACK`
  (SHA-256 `14E0BF26F1DDEF3AFCD107D68DA1C8EA943B62CBD6C56E85F93191158BD61E28`).
- `0051` ausente do histórico ao final da fase.

**Fase apply:**

- `db push --dry-run` selecionou exclusivamente `0051_m25_saas_billing_subscriptions`;
  push aplicou a 0051 (histórico 0001–0051).
- Pós-aplicação `M25_POST_APPLY_OK`; testes **38/38 + 28/28**; regressão M24
  **36/36 + 25/25**; preflight passou a recusar (esperado, já aplicada);
  REST anônimo `courses/products/cms_content/saas_plans` = **200** sem 42501.

**Resumo:** validate 6 passos OK; apply 15 passos OK; exit 0.
Logs: `staging/logs/m25-g0-remote-20260928-224126-validate.log`,
`staging/logs/m25-g0-remote-20260928-224204-apply.log`.

## 3. Pendências operacionais (fora do repositório)

1. **Painel do Mercado Pago:** configurar a URL de notificação
   `https://www.connectioncyber.com.br/api/payments/webhook` (o Preapproval do SDK não
   aceita `notification_url` por requisição) e usar credencial production + webhook secret
   (`MERCADOPAGO_ACCESS_TOKEN`, `MERCADOPAGO_WEBHOOK_SECRET`, `PAYMENTS_ENABLED=true`
   apenas em `VERCEL_ENV=production`).
2. **Preço real:** `update public.saas_plans set price_cents = <centavos> where code = 'padrao';`
3. **Homologação do fluxo completo no sandbox/production do MP** (checkout → webhook →
   empresa criada → convite por e-mail), que depende das credenciais acima.

## 4. Próximo portão

**R-003** (backup gerenciado + RPO/RTO) → **M14 lote real** (4.225 XMLs).
