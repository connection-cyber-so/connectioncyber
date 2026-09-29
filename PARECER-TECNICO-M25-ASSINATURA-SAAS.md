# Parecer Técnico M25-G0 - Assinatura SaaS mensal (Mercado Pago) com auto-provisionamento

**Data:** 28/09/2026
**Módulo:** M25 - Assinatura recorrente + criação automática de empresa
**Ambiente:** staging (`ozvylnaipubrmaadikvk`)
**Status:** aprovado para implementação e já executado (ver `RELATORIO-M25-G0-ENTREGA.md`)

## 1. Contexto e objetivo

O produto é um SaaS multi-tenant vendido por assinatura: o cliente paga mensalmente, a
empresa dele é **criada automaticamente** e ele entra com credenciais próprias. Até aqui o
site só vendia cursos/produtos pontuais (Preference + pedido). Este módulo fecha o ciclo
comercial: cartão salvo, cobrança recorrente e provisionamento sem toque humano no
primeiro pagamento aprovado.

Decisões firmadas com o responsável (28/09/2026):
- Cobrança **mensal recorrente** via **Mercado Pago Preapproval** (cartão salvo).
- **Automático ao pagar**: o provisionamento acontece no primeiro pagamento aprovado,
  encadeando o contrato de provisionamento já existente (migration 0034).
- Preço do plano: seed `saas_plans.price_cents = 19900` (R$ 199,00) é **placeholder
  ajustável** — `update saas_plans set price_cents = ... where code = 'padrao';`.

## 2. Decisão

1. **Modelo comercial parametrizado** (não hard-coded): `saas_plans` (plano + preço +
   trial) e `saas_plan_capabilities` (FK direta para `erp_capability_catalog.key`).
   Seed do plano `padrao` com 13 capabilities. Trocar de segmento/empresa é linha de
   dados, não migration.
2. **Fluxo de checkout em três atos**, todos service_role-only (`security definer`,
   `auth.role()` exigido, RLS fechada para `anon`/`authenticated`):
   - `saas_create_checkout_intent_v1` — cria a intenção com allow-list estrita do payload
     de empresa (sem senha/segredo, regex por campo, slug/domínio/CNPJ únicos contra
     `tenants`/`erp_establishments`), **idempotente** por usuário+plano; replay com dados
     corrigidos atualiza payload e hash (status `created`/`sent`).
   - `saas_bind_preapproval_v1` — vincula o `preapproval_id` do MP à intenção (`sent`).
   - `saas_activate_intent_v1` — no **pagamento aprovado**: `prepare → record → finalize`
     (contrato 0034), cria `saas_subscriptions` ativa, marca intenção `provisioned`.
     Idempotente; falha grava `failed` + `last_error` (trilha).
3. **Transições de estado por webhook**: `saas_set_subscription_status_v1` ativa/suspende
   as capabilities do plano via broker (`erp_set_tenant_capability`, `source='contract'`)
   para `cancelled`/`paused`/`past_due`; eventos do MP gravados em `saas_billing_events`
   com idempotência `(topic, external_id)`.
4. **Site**: tela `/planos` (catálogo via RLS anônima + formulário da empresa), endpoint
   `POST /api/payments/create-subscription` (bearer do Supabase Auth → intenção →
   Preapproval → bind → `init_point`), webhook bifurcado por tópico
   (`preapproval`/`preapproval_payment` → ciclo de vida da assinatura; demais → fluxo de
   pedidos inalterado). Lógica de decisão extraída em módulo puro
   (`subscriptionLifecycle`) coberto por `node:test`.
5. **Dono da empresa** = usuário logado no site no ato da assinatura. A conta precisa
   existir em `auth.users`/`public.users` (exigência do contrato 0034); o convite
   (`membership invited`, 72 h) sai pela outbox do próprio 0034.

## 3. Por que este desenho

- **Nada de "confiar no corpo do webhook":** o tópico é lido só para rotear; o estado vem
  de `Preapproval.get` (fonte da verdade no MP) antes de qualquer transição.
- **Fail-closed:** payload com campo fora da allow-list ou regex rejeitado; anon sem
  `execute` em nenhuma RPC; assinatura exige sessão; replay não duplica empresa.
- **Auditoria completa:** todo evento do MP vira linha em `saas_billing_events` antes da
  transição e é marcado `processed` com o resultado (`provisioned`, `status:cancelled`…).
- **Regressão blindada:** gate com transação única66 asserções `ROLLBACK` + regressão
  dos módulos 0049/0050.

## 4. Riscos residuais e decisões conscientes

| Risco | Mitigação/decisão |
|---|---|
| Comprador com assinatura ativa tenta assinar de novo | Endpoint devolve 409 (`saas_subscriptions` ativa do dono) |
| Payload corrigido após o checkout aberto | Replay atualiza payload/hash quando `created`/`sent` |
| Webhook chega com falha de MP | Erro → HTTP 500 → MP reenvia; evento idempotente por `(topic, external_id)` |
| Preço placeholder | Documentado no seed e no STATUS; ajuste é um `update` |
| `notification_url` do Preapproval | Depende da URL de notificação configurada no painel do MP (o SDK não expõe o campo); documentado no relatório |
| Provisionar duas empresas para o mesmo usuário (duas assinaturas) | Bloqueio por assinatura ativa do dono; membership `invited` de terceiro não bloqueia |

## 5. Próximos portões

M25 concluído → **R-003** (backup gerenciado + RPO/RTO) → **M14 lote real**
(4.225 XMLs em `C:\Users\joaqu\Downloads\SICNETNFS`, só após R-003).
