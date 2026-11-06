# RELATÓRIO M54-G5 — recebimento, coleta e despacho

Data: 06/11/2026 · Ambiente: staging `ozvylnaipubrmaadikvk` · Produção: intocada

## Escopo (migration 0059)
- `cd_receber_transferencia`: tira da loja (qtd e reservado) e põe no CD; a reserva do pedido passa da loja para o CD.
- `cd_coletar_pedido`: exige todas as transferências recebidas; baixa do CD na coleta (saldo e reserva consumidos).
- `cd_despachar_pedido`: pedido sem CD (balcão, shopee) dá baixa na loja; pedido com CD exige coleta antes.
- Funções `security definer`, `search_path=''`, execute só para `service_role`.

## Evidência
| Etapa | Resultado |
|---|---|
| Preflight | limpo, sem resíduo de teste |
| Ensaio transacional (migration + teste) | sem `FALHOU`, com ROLLBACK |
| Cenário FICTICIO | CD 45 + loja 55; web 60 (CD 45 + transferência 15); balcão 10 |
| Checagens | coleta com transferência pendente falha; recebimento move 15 (loja 40/10, CD 60/60); receber de novo falha; coleta zera CD (0/0); balcão despacha (loja 30/0); despachar de novo falha; disponível final 30 |
| Aplicação staging | 3 funções definer; sem resíduo |

## Pendências
1. `produto_id` sem FK até o catálogo.
2. Sem camada de API: as funções só rodam via `service_role` (gate de interface próximo).
3. Produção: exige autorização separada.
