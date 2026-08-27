# Validação M10-G2 — Supabase staging

Data: 27/08/2026

## Escopo autorizado

Aplicar exclusivamente a migration `0026_m10_food_service.sql` no projeto Supabase staging `ozvylnaipubrmaadikvk`, executar 72 asserções remotas e não criar mesas, comandas, pedidos, tickets, vendas ou dados reais.

## Validação preventiva

O primeiro preflight recusou a sintaxe compactada `DO$$` antes de qualquer escrita. Os delimitadores da migration, preflight e rollback foram corrigidos localmente para `DO $$` e `AS $$`. O preflight foi repetido e aprovado antes da aplicação.

## Evidências

1. branch confirmada: `staging`;
2. vínculo confirmado: `ozvylnaipubrmaadikvk`;
3. antes da aplicação, somente a migration `0026` estava pendente;
4. preflight após correção: `M10_PREFLIGHT_OK`;
5. dry-run selecionou exclusivamente `0026_m10_food_service.sql`;
6. aplicação remota concluída sem seed, roles ou migrations adicionais;
7. suíte pgTAP: `72/72` aprovada;
8. histórico local/remoto alinhado de `0001` a `0026`;
9. dry-run final: banco remoto atualizado, zero migrations pendentes.

## Auditoria de dados

| Conjunto | Registros |
|---|---:|
| Áreas do salão | 0 |
| Mesas | 0 |
| Sessões de mesa | 0 |
| Comandas | 0 |
| Pedidos | 0 |
| Tickets de cozinha | 0 |
| Vendas originadas por alimentação | 0 |

## Resultado

M10 aplicado e validado exclusivamente no Supabase staging. Produção não foi vinculada, consultada ou alterada.
