# RELATÓRIO 0062 · PDV entregas: entregador, falha de entrega, taxa e zonas por raio

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).

## Escopo

1. `erp_food_fulfillments`: colunas `courier_kind`, `courier_party_id` (FK composta para `erp_parties`), `courier_name`, `attempts`, `failure_reason`, `failed_at`, `distance_km`, `delivery_fee`, `fee_charge_mode`.
2. Status `failed`, com constraint exigindo `failure_reason` e `failed_at`.
3. `erp_delivery_fee_zones`: faixas de taxa por raio por estabelecimento, com trigger que impede sobreposição (intervalo `[from, to)`), RLS (`food.read` / `food.manage`) e sem acesso para `anon`.

Decisões: taxa suportada nos dois casos (item da venda com `fee_charge_mode = 'in_sale'` e campo do pedido de entrega `delivery_fee`), com zonas por raio como cadastro. Interpretação de "terenos os dois casos" registrada aqui para revisão.

## Evidências

| Etapa | Resultado |
|---|---|
| Preflight | 9/9 OK (0 linhas em `erp_food_fulfillments`; colunas novas ausentes; tabela de zonas ausente) |
| Migration | Aplicada com sucesso no staging |
| Pós-aplicação | Status com `failed`, constraint de motivo presente, FKs de entregador, RLS ativo com 4 policies, trigger presente, `anon` sem acesso, zero linhas residuais |
| Testes A–C | Defaults, status com `failed`, zonas (sobreposição bloqueada, faixa encostada permitida, taxa negativa rejeitada): passaram |
| Teste D | Falha sem motivo bloqueada pela constraint `erp_food_fulfillments_failure_reason_check` (confere o nome exato); falha com motivo aceita. Passou. Comanda de teste criada dentro da transação e descartada por ROLLBACK |
| Arquivo completo | `supabase/tests/0062_...test.sql` executado de ponta a ponta no staging: passou |

## Correções feitas durante a execução

- Teste original fixava um tenant de teste que pode não existir: trocado por seleção dinâmica.
- Teste D passava em silêncio se não houvesse comanda: agora cria a própria comanda.
- Teste D aceitava qualquer `check_violation`: agora confere a constraint pelo nome.
- Teste E era um no-op: removido.

## Pendências

- 0063 não criada.
- `STATUS-MESTRE-DESENVOLVIMENTO` atualizado nesta mesma rodada (ver entrada PDV).
- Commit não feito (aguarda "commit local"). Push não feito (aguarda "push").

## Arquivos

- `supabase/migrations/0062_pdv_entregas_entregador_falha_taxa.sql`
- `supabase/preflight/0062_pdv_entregas_entregador_falha_taxa_preflight.sql`
- `supabase/tests/0062_pdv_entregas_entregador_falha_taxa.test.sql`
- `supabase/rollback/0062_pdv_entregas_entregador_falha_taxa.rollback.sql`
- `RELATORIO-0062-entregas-entregador-falha-taxa.md` (este arquivo)
