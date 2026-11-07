# RELATÓRIO 0066 · PDV alçada de caixa: sangria acima do limite e fechamento com diferença

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).

## Escopo

Fecha a lacuna de alçada em `cash.adjust` (sangria) e `cash.close` (fechamento), apontada no relatório 0065.

1. **Sangria** (`withdrawal`): exige `cash.adjust`. Acima de `pdv.cash.withdrawal_limit_amount` exige autorização de mesmo valor, da mesma sessão, feita por outra pessoa e usada uma única vez. Trigger `erp_cash_movements_guard_trg`.
2. **Fechamento**: diferença entre contado e esperado (≠ 0) exige autorização de fechamento com o valor absoluto da diferença. `erp_command_close_cash_v1` aceita `authorizationId` no payload e grava `difference_amount` real (antes era fixo em 0 com erro `cash difference`).
3. **RPC** `erp_authorize_cash_action`: única forma de gravar `erp_cash_authorizations`. Insert direto não é concedido a `authenticated`.

Regras da RPC:
- Sessão autenticada; aprovador com `cash.adjust` (sangria) ou `cash.close` (fechamento).
- Solicitante = membro ativo e vigente do tenant, diferente do aprovador.
- Sessão existe e não está `closed`.
- Sangria só gera alçada acima do limite; fechamento só gera alçada com diferença ≠ 0.

## Decisões propostas (não aprovadas)

- Limite de sangria sem autorização: **500,00** (`pdv.cash.withdrawal_limit_amount`, semeado nos 8 tenants). Valor de partida, a validar com o responsável.
- Qualquer diferença de caixa exige autorização de fechamento, sem tolerância automática. A validar.

## Fora deste gate

- PIN ou MFA do aprovador (decisão pendente, igual à 0065).
- Alçada de suprimento e de estorno.
- Tolerância de diferença por valor, se o negócio quiser.

## Evidências

| Etapa | Resultado |
|---|---|
| Preflight (read-only) | Constraint `unique (tenant_id,id)` em `erp_cash_sessions` já existia. Migration foi ajustada para não recriá-la. |
| Primeira aplicação | Falhou com `42P07` (constraint duplicada). Transação revertida, nada aplicado. Corrigido e reaplicado. |
| Migration | Aplicada com sucesso no staging. |
| Teste A–V | Passou sem exceção (`rollback` ao final, zero linhas residuais). Cobre: privilégios da RPC; sangria dentro e acima do limite; autorização exata, divergente, reutilizada (23505), indevida dentro do limite, em tipo que não é sangria; usuário sem permissão (42501); saldo esperado; diferença sem alçada; alçada de fechamento com valor exato; sem diferença; autoaprovação; helper com valor divergente; autorização já consumida; sessão fechada (55000). |
| Pós-aplicação | `anon` sem execução da RPC; `authenticated` com execução; RLS ativo na tabela; sem insert direto para `authenticated`; trigger presente; `erp_command_close_cash_v1` chama o helper; limite semeado em 8/8 tenants; zero linhas residuais (`erp_cash_*`, `T0066-%`). |

## Teste de integração do fechamento

Arquivo: `supabase/tests/0066_pdv_alcada_caixa_fechamento_integracao.test.sql`. Passou no staging, com rollback.

Cobre o fluxo real pela camada de comandos (`erp_command_close_cash_v1`, com `request_id`, hash SHA-256 do payload e recibo):
1. Fechamento com diferença de -10 sem autorização é negado (23514).
2. Aprovador autoriza a diferença exata.
3. Operador fecha com `authorizationId`: sessão `closed`, `difference_amount` = -10.
4. Replay com mesmo `request_id` e hash devolve o resultado salvo, sem erro.

## Limitações

- Os testes de sangria e de RPC (0066) não cobrem a limpeza de recibos de comando. O teste de integração cobre o fechamento, mas não a concorrência entre dois fechamentos simultâneos.
- O aprovador não reconfirma identidade (PIN ou MFA).
- O solicitante da sangria é validado pelo `auth.uid()` da sessão que insere o movimento. Quem insere precisa ser o mesmo solicitante da autorização.

## Arquivos

- `supabase/migrations/0066_pdv_alcada_caixa_sangria_fechamento.sql`
- `supabase/preflight/0066_pdv_alcada_caixa_sangria_fechamento_preflight.sql`
- `supabase/tests/0066_pdv_alcada_caixa_sangria_fechamento.test.sql`
- `supabase/rollback/0066_pdv_alcada_caixa_sangria_fechamento.rollback.sql` (somente laboratório; restaurar `erp_command_close_cash_v1` de `0033_m17_persistent_journey.sql` antes de remover helpers)
- `RELATORIO-0066-alcada-caixa-sangria-fechamento.md` (este arquivo)

## Pendências

- Commit: não feito (aguarda "commit local"). Push: não feito (aguarda "push").
- Confirmar o limite de 500,00 e a regra de qualquer diferença exige alçada.
- PIN ou MFA do aprovador, se decidido.
- Teste de integração do fechamento pela camada de comandos.
