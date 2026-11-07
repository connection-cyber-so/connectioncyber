# RELATÓRIO 0065 · PDV alçada de desconto: aprovador e solicitante validados por RPC

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).

## Escopo

Fecha a lacuna apontada no relatório 0063: o insert direto em `erp_discount_authorizations` deixa de existir para `authenticated`. Toda autorização passa por `public.erp_authorize_discount(...)`.

Regras da RPC:

1. Sessão autenticada (`auth.uid()`) com `sales.discount` no tenant = aprovador.
2. Solicitante = membro ativo do tenant (membership ativa e vigente, usuário e tenant ativos).
3. Aprovador diferente do solicitante.
4. Desconto acima do limite configurado (`pdv.discount.auto_limit_percent`, padrão 5). Abaixo do limite não há alçada a registrar.
5. O limite usado é gravado junto da autorização (`limit_percent`).

Fora deste gate: PIN ou MFA do aprovador (decisão futura) e alçada de sangria e fechamento.

## Mudanças em relação à 0063

- Removida a policy `erp_discount_authorizations_insert`.
- Revogado `insert` de `authenticated` na tabela.
- Criada a função `erp_authorize_discount` (security definer, `search_path = ''`, execute apenas para `authenticated`).

## Evidências

| Etapa | Resultado |
|---|---|
| Preflight | 8/8 OK (candidatos a aprovador: 5 tenants; alçada com 0 linhas) |
| Migration | Aplicada com sucesso no staging |
| Testes A–H | Passaram: função com security definer e search_path fixo; `anon` sem execução; insert direto negado; sem sessão bloqueado (42501); aprovador sem permissão bloqueado (42501); autoaprovação bloqueada (23514); solicitante não membro bloqueado (42501); desconto dentro do limite bloqueado (23514); caso válido gravado com `approved_by` e `requested_by` corretos |
| Pós-aplicação | `anon` sem execução; `authenticated` com execução; insert direto removido; policy removida; zero linhas residuais |

Correção durante a execução: a primeira versão do teste escolhia um aprovador de um tenant com um único membro, e o teste pularia o caso do solicitante sem avisar. Agora o aprovador é escolhido só entre tenants com outro membro ativo, e a falta de candidato falha o teste em vez de pular.

## Arquivos

- `supabase/migrations/0065_pdv_alcada_desconto_rpc.sql`
- `supabase/preflight/0065_pdv_alcada_desconto_rpc_preflight.sql`
- `supabase/tests/0065_pdv_alcada_desconto_rpc.test.sql`
- `supabase/rollback/0065_pdv_alcada_desconto_rpc.rollback.sql`
- `RELATORIO-0065-alcada-desconto-rpc.md` (este arquivo)

## Limitações

- O aprovador não reconfirma identidade (PIN ou MFA) no momento da autorização. Hoje basta a sessão dele estar ativa e ter `sales.discount`.
- Sangria e fechamento usam `cash.adjust` e `cash.close`, sem alçada de aprovação.

## Pendências

- Commit: não feito (aguarda "commit local"). Push: não feito (aguarda "push").
- Alçada de sangria e fechamento (próximo gate).
- PIN ou MFA do aprovador, se decidido.
