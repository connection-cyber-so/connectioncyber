# RELATÓRIO 0069 · PDV auditoria do PIN, auto-PIN do gerente e integração no portal

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).
Complementa: `RELATORIO-0068-pdv-pin-gerente.md`.

## Decisões (aprovadas pelo responsável em 07/11/2026)

- Cadastro de PIN exige trilha de auditoria.
- Gerente pode ter PIN próprio só se o tenant ligar a configuração `pdv.alcada.allow_self_pin` (configurável; padrão desligado).
- Aprovação da própria solicitação continua proibida (solicitante ≠ aprovador, como em 0063/0065/0066).
- Cadastro de PIN continua restrito a Administrador e Proprietário (`memberships.manage`).
- Atualizar o `apps/portal` para `p_pin`, retorno `jsonb` e cadastro de PIN pelo gerente.

## Escopo do banco (0069)

1. Tabela `erp_approver_pin_audit`: `tenant_id`, `target_user_id`, `changed_by`, `action` (`set`), `is_self`, `created_at`. Não guarda PIN nem hash. Check garante `is_self = (target = autor)`.
2. RLS: leitura só para quem tem `memberships.manage` ou staff da plataforma. Sem insert, update ou delete para `anon` e `authenticated`; a escrita é feita pela função `security definer`.
3. Trigger `erp_approver_pin_audit_immutable`: bloqueia `UPDATE` e `DELETE` (SQLSTATE 42501).
4. Seed `pdv.alcada.allow_self_pin` = `{"enabled": false}` nos 8 tenants.
5. `erp_manager_set_approver_pin`: se o alvo é o próprio gerente, exige a configuração ligada (senão 42501); grava a auditoria a cada cadastro bem-sucedido.

## Escopo do app (`apps/portal`)

- `src/domain/pdv-alcada.ts`: contrato puro. Valida PIN (4 a 6 dígitos), converte o jsonb das RPCs (falha fechada em retorno fora do contrato), define quando a alçada pode ser gravada (só `authorized`) e as mensagens ao operador (inclui bloqueio de 15 minutos e PIN ausente).
- `src/features/pdv-alcada/service.ts` (`server-only`): chama `erp_authorize_discount`, `erp_authorize_cash_action` e `erp_manager_set_approver_pin` com a sessão do usuário. Tenant vem do parâmetro do chamador, que deve vir do contexto do portal.
- `tests/pdv-alcada.test.ts`: 6 testes, todos aprovados.

## Evidências

| Etapa | Resultado |
|---|---|
| Preflight 0069 (leitura, antes de aplicar) | Passou sem exceção. 8 tenants sem a configuração (o seed preenche). |
| Migration 0069 | Aplicada no staging com sucesso. |
| Teste `0069_pdv_auditoria_pin_e_auto_pin_gerente.test.sql` | Passou sem erro. Cenários: A auto-PIN desligado → 42501; B gerente cadastra PIN de outro → ok, auditoria `is_self=false`, autor = gerente; C configuração ligada → auto-PIN ok, `is_self=true`; D update e delete na auditoria bloqueados (42501); E ator sem vínculo → 42501. Transação revertida. |
| `tsc --noEmit` (apps/portal) | Código 0. |
| `tests/pdv-alcada.test.ts` | 6/6 aprovados. |
| Suíte completa do portal | 168/168 aprovados. A falha anterior (`m18-g22-mfa-security.test.ts`) foi corrigida: `CrmShell.tsx` usava o client do navegador só para `signOut`; agora o botão "Sair" é um form POST para `/auth/logout` (rota server já existente, mesmo padrão de `(portal)/layout.tsx`). |
| Teste `0067_pdv_pin_aprovador.test.sql` (rodado de novo) | Passou sem erro. Correção: o gerente de teste agora é fixo (`e2b88e26`). Antes, `limit 1` podia escolher o aprovador `72d1f5ee`, que também tem `memberships.manage`; o cadastro dele virava auto-PIN e a 0069 corretamente bloqueava. |

## Achado durante o teste

- O usuário aprovador de teste (`72d1f5ee`) também tem `memberships.manage`. Por isso o primeiro desenho do teste (gerente cadastrando o próprio aprovador) virou autoatribuição e falhou. O teste foi reescrito com gerente `e2b88e26` e alvo `72d1f5ee`.
- Não existe, no tenant de teste, membro com alçada e sem `memberships.manage`. Um cenário "aprovador comum" depende de fixture nova.

## Arquivos

- `supabase/migrations/0069_pdv_auditoria_pin_e_auto_pin_gerente.sql`
- `supabase/preflight/0069_pdv_auditoria_pin_e_auto_pin_gerente_preflight.sql`
- `supabase/tests/0069_pdv_auditoria_pin_e_auto_pin_gerente.test.sql`
- `supabase/rollback/0069_pdv_auditoria_pin_e_auto_pin_gerente.rollback.sql` (apaga a auditoria: só laboratório)
- `apps/portal/src/domain/pdv-alcada.ts`
- `apps/portal/src/features/pdv-alcada/service.ts`
- `apps/portal/tests/pdv-alcada.test.ts`
- `RELATORIO-0069-pdv-auditoria-pin-auto-pin-gerente.md` (este arquivo)

## Pendências e limitações

- Regressão do 0067: resolvida (gerente fixo no teste).
- **Wiring das telas:** `DemoPos.tsx` e `DemoCash.tsx` são demo com estado local. Os testes `demo-cash` e `demo-pos` exigem que não usem Supabase. Ligar as telas às RPCs exige mudar esses testes: decisão pendente.
- Auditoria registra só cadastros bem-sucedidos. Tentativas de PIN errado continuam só no contador de `erp_approver_pins`.
- Um gerente pode ter PIN próprio quando a configuração está ligada. Ele ainda não pode aprovar a própria solicitação (regra de solicitante ≠ aprovador).
- Sem MFA: PIN é controle de alçada, não autenticação forte.
- Commit e push: não feitos (aguardam "commit local" e "push").
