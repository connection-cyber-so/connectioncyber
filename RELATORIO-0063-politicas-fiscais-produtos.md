# RELATÓRIO 0063 · PDV políticas fiscais e de desconto

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`).

## Escopo

1. `erp_catalog_items`: `age_restricted` (+18) e `fumigeno`, com duas regras:
   - fumígeno exige +18;
   - fumígeno não pode ser fracionado.
2. `erp_discount_authorizations`: registro de alçada para desconto acima do limite. Exige `discount_percent > limit_percent`, aprovador diferente do solicitante e motivo com 3+ caracteres. RLS: leitura por `sales.discount` ou `sales.read`; escrita por `sales.discount` com `approved_by = auth.uid()`.
3. Seed de `erp_tenant_settings` (nível tenant, idempotente) para os 8 tenants:
   - `pdv.discount.auto_limit_percent` = `{"percent": 5}`;
   - `pdv.fiscal.emit_nfce_by_channel` = `{"balcao": true, "app": false, "site": false, "ifood": false}`;
   - `pdv.kitchen.print_on_accept` = `{"enabled": true}`.

## Decisões aplicadas

- Flags +18 e fumígeno como colunas tipadas.
- Limite de desconto automático: 5%, configurável por tenant, não automático.
- NFC-e por canal: balcão emite; app, site e iFood não emitem automaticamente (configurável).
- Sangria e fechamento usam `cash.adjust` e `cash.close` (já existentes). Não há alçada de aprovação para esses dois casos nesta versão.

## Limitações conhecidas

- O banco não confere se o aprovador tem permissão no momento da gravação; a RLS confere apenas se quem grava é o aprovador (`approved_by = auth.uid()`) e tem `sales.discount`. Validação completa (aprovador ativo no tenant, com PIN ou MFA) fica para uma RPC dedicada.
- O limite de 5% é lido das configurações, mas a comparação é feita pela aplicação, não pelo banco.
- Alçada para sangria e fechamento: não implementada.

## Evidências

| Etapa | Resultado |
|---|---|
| Preflight | 10/10 OK (8 tenants; seeds ainda ausentes) |
| Migration | Aplicada com sucesso no staging |
| Testes A–I | 9 cenários passaram (default false; fumígeno sem +18 bloqueado; fumígeno fracionado bloqueado; fumígeno válido aceito; desconto abaixo do limite bloqueado; aprovador = solicitante bloqueado; motivo curto bloqueado; autorização válida aceita; seeds completos). Transação com ROLLBACK |
| Pós-aplicação | RLS ativo; 2 policies; `anon` sem acesso; sem UPDATE/DELETE para `authenticated`; zero linhas residuais; seeds em 8 tenants; flags com default false; 2 constraints presentes |

## Arquivos

- `supabase/migrations/0063_pdv_politicas_fiscais_produtos.sql`
- `supabase/preflight/0063_pdv_politicas_fiscais_produtos_preflight.sql`
- `supabase/tests/0063_pdv_politicas_fiscais_produtos.test.sql`
- `supabase/rollback/0063_pdv_politicas_fiscais_produtos.rollback.sql`
- `RELATORIO-0063-politicas-fiscais-produtos.md` (este arquivo)

## Pendências

- Commit: não feito (aguarda "commit local"). Push: não feito (aguarda "push").
- Validação de aprovador via RPC (próximo gate).
- Alçada para sangria e fechamento.
- `claude/PDV-mapeamento-erp.md` no projeto: não atualizado.
