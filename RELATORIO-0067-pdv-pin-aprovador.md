# RELATÓRIO 0067 · PDV PIN do aprovador (desconto e caixa)

> **Atualização 07/11/2026:** o item de autoatendimento (`erp_set_approver_pin`) foi removido pela 0068. Hoje o PIN é cadastrado pelo gerente (`erp_manager_set_approver_pin`, permissão `memberships.manage`). Ver `RELATORIO-0068-pdv-pin-gerente.md`. As seções abaixo sobre autoatendimento descrevem o estado da 0067 e ficam para histórico.
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).

## Decisões (aprovadas pelo responsável em 07/11/2026)

- PIN vale para alçada de **caixa** (sangria, fechamento) e de **desconto**.
- Após 5 erros seguidos, bloqueio de **15 minutos**. Durante o bloqueio, nem o PIN certo é aceito.
- Limite de sangria sem alçada: 500,00 (confirmado).
- Diferença de caixa ≠ 0 exige alçada (confirmado).

## Escopo

1. Tabela `erp_approver_pins` (uma linha por tenant e usuário). Sem acesso direto: RLS ligado, nenhum grant para `anon` ou `authenticated`. Guarda só o hash bcrypt.
2. `erp_set_approver_pin(p_tenant_id, p_new_pin, p_current_pin)`: o próprio usuário define ou troca o PIN. Troca exige o PIN atual. PIN com 4 a 6 dígitos. Exige alguma permissão de alçada (`sales.discount`, `cash.adjust` ou `cash.close`).
3. `erp_check_approver_pin` (interna, sem grant): compara o PIN, conta erros e aplica bloqueio. Não lança exceção no erro de PIN. Isso preserva o contador de erros, porque uma exceção desfaria a escrita.
4. `erp_authorize_discount` e `erp_authorize_cash_action` ganham o parâmetro `p_pin` e passam a devolver `jsonb`:
   - `{ "status": "authorized", "authorization_id": "<uuid>" }`
   - `{ "status": "pin_invalid" | "pin_locked" | "pin_missing" }`
   As validações de permissão, solicitante, limite e sessão continuam lançando exceção, como antes. A verificação de PIN vem depois delas.

## Mudança para quem chama a RPC

- Enviar `p_pin` como último parâmetro.
- Ler `status` no retorno. Só gravar a alçada no fluxo de venda ou caixa quando `status = 'authorized'`.
- Tratar `pin_locked` com mensagem de espera de 15 minutos. Tratar `pin_missing` com orientação para cadastrar o PIN.

## Evidências

| Etapa | Resultado |
|---|---|
| Migration | Aplicada no staging com sucesso. |
| Preflight | Arquivo criado. Rodado após a aplicação, então não serve como validação prévia. |
| Teste `0067_pdv_pin_aprovador.test.sql` | Passou (A–I): privilégios; ausência de PIN; PIN errado; quinto erro bloqueia; PIN certo durante bloqueio negado; desbloqueio e reset de contador; troca de PIN; PIN com dígitos inválidos; usuário sem permissão; sangria com PIN errado e certo; fechamento com PIN certo. |
| Teste `0065` (atualizado) | Passou. Usa PIN e lê `jsonb`. |
| Teste `0066` principal (atualizado) | Passou. Usa PIN e lê `jsonb`. |
| Teste `0066` integração (atualizado) | Passou. Fechamento pela camada de comandos com autorização por PIN. |
| Verificação de privilégios | `anon` sem execução das RPCs de PIN. `authenticated` sem `EXECUTE` em `erp_check_approver_pin`. |

## Arquivos

- `supabase/migrations/0067_pdv_pin_aprovador.sql`
- `supabase/preflight/0067_pdv_pin_aprovador_preflight.sql`
- `supabase/tests/0067_pdv_pin_aprovador.test.sql`
- `supabase/tests/0065_pdv_alcada_desconto_rpc.test.sql` (atualizado para a assinatura com PIN)
- `supabase/tests/0066_pdv_alcada_caixa_sangria_fechamento.test.sql` (atualizado)
- `supabase/tests/0066_pdv_alcada_caixa_fechamento_integracao.test.sql` (atualizado)
- `supabase/rollback/0067_pdv_pin_aprovador.rollback.sql` (laboratório; recriar 0065 e 0066 antes de usar)
- `RELATORIO-0067-pdv-pin-aprovador.md` (este arquivo)

## Limitações

- Sem limite global de tentativas por IP ou sessão. O bloqueio é por aprovador e tenant.
- O PIN é fraco contra quem já tem a sessão do aprovador e conhece o PIN. É controle de alçada, não autenticação forte. Se o risco exigir, MFA é o próximo passo.
- Quem já tem `sales.discount`, `cash.adjust` ou `cash.close` pode definir o próprio PIN sem gerente. Se o gerente deve cadastrar, é preciso outra regra.
- Tela do app que chama as RPCs: não alterada neste gate (fora do repositório do banco).

## Pendências

- Commit: não feito (aguarda "commit local"). Push: não feito (aguarda "push").
- Atualizar o app para a nova assinatura (`p_pin`, retorno `jsonb`).
- Decidir se o gerente cadastra o PIN ou o próprio aprovador.
