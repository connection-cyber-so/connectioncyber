# Validação M09-G2 — Supabase staging

Data: 27/08/2026

## Escopo autorizado

Aplicar exclusivamente a migration `0025_m09_services_workshops.sql` no projeto Supabase staging `ozvylnaipubrmaadikvk`, executar 68 asserções remotas e não criar ativos, agendas, ordens de serviço, vendas ou dados reais.

## Evidências

1. branch confirmada: `staging`;
2. vínculo confirmado: `ozvylnaipubrmaadikvk`;
3. antes da aplicação, somente a migration `0025` estava pendente;
4. preflight remoto: `M09_PREFLIGHT_OK`;
5. dry-run selecionou exclusivamente `0025_m09_services_workshops.sql`;
6. aplicação remota concluída sem seed, roles ou migrations adicionais;
7. suíte pgTAP: `68/68` aprovada;
8. histórico local/remoto alinhado de `0001` a `0025`;
9. dry-run final: banco remoto atualizado, zero migrations pendentes.

## Auditoria de dados

| Conjunto | Registros |
|---|---:|
| Ativos | 0 |
| Agendamentos | 0 |
| Ordens de serviço | 0 |
| Itens de OS | 0 |
| Vendas originadas por serviços | 0 |
| Garantias | 0 |

## Resultado

M09 aplicado e validado exclusivamente no Supabase staging. Produção não foi vinculada, consultada ou alterada.
