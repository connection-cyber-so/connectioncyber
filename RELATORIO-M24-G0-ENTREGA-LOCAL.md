# Relatório M24-G0 — Envio ao contador: entrega local e gate de staging

**Data:** 28/09/2026
**Executor:** automação (execução ponta a ponta autorizada pelo responsável)
**Ambientes:** local (stack Supabase + `apps/portal`) e staging (`ozvylnaipubrmaadikvk`)
**Produção:** não alterada

## 1. O que foi entregue

| Artefato | Conteúdo |
|---|---|
| `supabase/migrations/0050_m24_accountant_delivery.sql` | Papel `contador`, `is_accountant()`, 3 tabelas (`erp_accountant_packages`, `erp_accountant_package_files`, `erp_accountant_delivery_events`) com RLS fail-closed, permissão `fiscal.deliver`, 5 RPCs (`publish`, `list`, `ack`, `void`, `log_download`), bucket `fiscal-deliveries` + 5 storage policies |
| `supabase/rollback/0050_...rollback.sql` | Rollback completo (não dropa extensões) |
| `supabase/tests/0050_....test.sql` | Estrutural — **plan(36)** |
| `supabase/tests/0050_....adversarial.test.sql` | Adversarial — **plan(25)** (cross-tenant, RLS, idempotência, void, caminho malicioso, claims trocadas) |
| `supabase/preflight/0050_..._preflight.sql` | Read-only; recusa pré e pós-aplicação |
| `supabase/validation/build-0050-transaction.mjs` + `0050_transaction.generated.sql` | Transação única migration+testes com **ROLLBACK** (61 asserções) |
| `supabase/verification/0050_post_apply.sql` | Auditoria pós-aplicação com marcador `M24_POST_APPLY_OK` |
| `supabase/validation/run-0050-remote.ps1` | Runner remoto `validate`/`apply`/`verify` |
| `apps/portal/src/app/(portal)/fiscal/contador/page.tsx` | Tela: dono publica (month + files múltiplos), contador lista todos os tenants, recibo e anulação |
| `apps/portal/src/app/(portal)/fiscal/contador/route.ts` | POST `publicar` (upload com validação fail-closed + SHA-256 servidor), `ack`, `void`; redireciona com resultado |
| `apps/portal/src/features/fiscal/service.ts` | Service server-only: visão dono (RLS) × visão contador (RPC auditada) + signed URLs |
| `apps/portal/src/app/(portal)/layout.tsx` | Link "Envio ao contador" na navegação |

## 2. Evidências de execução

### 2.1 Local

- Migration aplicada localmente (`psql` em `supabase_db_connectioncyber`, `ON_ERROR_STOP=1`).
- Estrutural **36/36**; adversarial **25/25** (após corrigir: nome de constraint truncado,
  cast `::uuid`, claims do dono antes do RLS, `set local role authenticated` na checagem do
  contador e void de pacote confirmado limpando campos de ack).
- Portal: `next lint` sem avisos; `tsc --noEmit` sem erros fora de artefatos `.next`;
  testes Node **155/155**.

### 2.2 Staging (runner `run-0050-remote.ps1`)

**Fase validate (sem escrita persistente):**

- Preflight `M24_PREFLIGHT_OK` (1/2) e re-execução pós-transação (2/2) = prova de resíduo zero.
- Transação **61/61** com marcador `M24_0050_TRANSACTION_61_OF_61_ROLLBACK`
  (SHA-256 `C33D52FB36D8C6405A66BD8ABEA6F2EFAD4A14A961D79F327143E2B7ED1DBEA9`).
- `0050` ausente do histórico ao final da fase.

**Fase apply:**

- Dry-run selecionou exclusivamente `0050_m24_accountant_delivery.sql`.
- `supabase db push` → `Finished supabase db push` (histórico 0001–0050).

**Fase verify:**

- Pós-aplicação `M24_POST_APPLY_OK` (tabelas, papel `contador` em `public.roles`,
  permissão `fiscal.deliver`, bucket, 5 policies, anon sem select, RPCs registradas).
- Testes remotos: **36/36** + adversarial **25/25**.
- Regressão M23: **12/12** + **24/24**.
- Preflight pós-aplicação recusou (esperado — idempotência do gate).
- REST anônimo: `courses`/`products`/`cms_content` = 200, zero `42501`.

### 2.3 Correções durante o gate

1. Preflight: `public.erp_security.has_permission` é nome cross-database → corrigido para
   `erp_security.has_permission`; consultas de privilégio de tabela ainda inexistente
   removidas do preflight; marcador movido para a última query com linhas (a API Management
   devolve só o último result set).
2. Pós-aplicação: "contador" é registro de `public.roles` (papel de negócio), não role de
   Postgres — checagens corrigidas de `pg_roles` para `public.roles`.

## 3. Decisões do portão

- **Aprovado em staging.** Produção intocada; promoção 0050→produção só em portão próprio,
  junto com os demais módulos pendentes.
- Repositório estava **vinculado ao projeto de produção** (`qfg`) após a promoção de
  28/09; foi **relinkado ao staging** (`ozvy`) antes de qualquer operação — corrigir o link
  evitou aplicar o M24 em produção sem autorização.

## 4. Pendências transferidas

- **M25** (assinatura MP + auto-provisionamento) → próximo portão.
- **R-003** (backup gerenciado, RPO/RTO) → obrigatório antes do M14 lote real.
- **M14 lote real**: 4.225 XMLs em `C:\Users\joaqu\Downloads\SICNETNFS` (16 clientes que não
  correspondem aos 5 tenants atuais — mapear no portão); `.bak` SQL Server e PFXs com senha
  no nome do arquivo exigem tratamento de credencial.
