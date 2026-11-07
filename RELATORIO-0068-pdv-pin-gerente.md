# RELATÓRIO 0068 · PDV PIN cadastrado pelo gerente

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).
Supera: parte do `RELATORIO-0067-pdv-pin-aprovador.md` (autoatendimento de PIN).

## Decisões (aprovadas pelo responsável em 07/11/2026)

- Quem configura a regra e cadastra PIN: Administrador e Proprietário (permissão `memberships.manage`).
- O aprovador não define o próprio PIN. Motivo: com autoatendimento, quem tem alçada poderia cadastrar um PIN próprio e contornar o controle.
- Reset de PIN esquecido = gerente cadastra outro PIN. O gerente não lê o PIN atual (só o hash é guardado).
- Demais regras da 0067 mantidas: PIN de 4 a 6 dígitos; 5 erros bloqueiam por 15 minutos; vale para desconto e caixa.

## Escopo

1. Remove `erp_set_approver_pin(uuid, text, text)` (autoatendimento).
2. Cria `erp_manager_set_approver_pin(p_tenant_id, p_target_user_id, p_new_pin) returns text`:
   - caller precisa de `memberships.manage` (ou staff da plataforma), senão `42501`;
   - PIN deve casar `^[0-9]{4,6}$`, senão `22023`;
   - alvo precisa ser membro ativo do tenant (usuário ativo, tenant ativo, dentro da vigência), senão `42501`;
   - alvo precisa ter `sales.discount`, `cash.adjust` ou `cash.close`, senão `23514`;
   - grava o hash e zera `failed_attempts` e `locked_until` (o gerente também desbloqueia por esta via).
3. Grant de execução só para `authenticated`; revoke de `public` e `anon`.

## Evidências

| Etapa | Resultado |
|---|---|
| Migration `0068_pdv_pin_cadastrado_pelo_gerente.sql` | Aplicada no staging com sucesso. |
| Teste `0067_pdv_pin_aprovador.test.sql` (versão do gerente) | Rodado de novo em 07/11/2026, dentro de `begin ... rollback`, sem erro. Cobre: PIN antigo recusado após cadastro do gerente; PIN novo aceito; PIN de 2 dígitos recusado (22023); usuário sem permissão recusado (42501); sangria com PIN errado (`pin_invalid`) e certo (`authorized`); fechamento com PIN certo. |
| Verificação pós-aplicação (somente leitura) | `erp_set_approver_pin` inexistente; `erp_manager_set_approver_pin` existente; `anon` sem EXECUTE; `authenticated` com EXECUTE; `authenticated` sem EXECUTE em `erp_check_approver_pin`; RLS ligado em `erp_approver_pins`. |
| Preflight `supabase/preflight/0068_pdv_pin_gerente_preflight.sql` | Escrito. Não foi rodado antes da aplicação; serve para aplicar de novo ou antes de rollback. Após a 0068, o item 4 é esperado como aviso (função removida). |

## Arquivos

- `supabase/migrations/0068_pdv_pin_cadastrado_pelo_gerente.sql`
- `supabase/preflight/0068_pdv_pin_gerente_preflight.sql`
- `supabase/rollback/0068_pdv_pin_gerente.rollback.sql` (recria o autoatendimento da 0067 e remove a função de gerente; sem perda de dados)
- `supabase/tests/0067_pdv_pin_aprovador.test.sql` (reescrito para o cadastro pelo gerente)
- `RELATORIO-0068-pdv-pin-gerente.md` (este arquivo)

## Limitações

- O gerente não tem trilha de auditoria própria do cadastro de PIN. Não há registro de quem cadastrou nem quando além de `updated_at`. Se o risco exigir, gravar evento em tabela de auditoria é o próximo passo.
- Sem limite global de tentativas por IP ou sessão. O bloqueio é por aprovador e tenant.
- Um gerente pode cadastrar PIN para si mesmo e usar o próprio PIN como aprovador. Não foi pedida separação de funções; registrar como decisão a confirmar.
- O PIN é controle de alçada, não autenticação forte. Se o risco exigir, MFA é o próximo passo (ainda não decidido).
- Tela do app que chama as RPCs: não alterada neste gate (fora do repositório do banco).

## Pendências

- Commit: não feito (aguarda "commit local"). Push: não feito (aguarda "push").
- Atualizar o app para `p_pin`, retorno `jsonb` e cadastro de PIN pelo gerente.
- Confirmar se um gerente pode aprovar a própria alçada.
- Decidir se haverá auditoria do cadastro de PIN.
