# RELATÓRIO 0064 · Ordens de produção ligadas à ficha técnica

Data: 07/11/2026
Ambiente: staging (`ozvylnaipubrmaadikvk`). Production: não tocado.
Código do módulo/gate: a confirmar (ex.: `M?-G?`). Este relatório usa o nome do tema até o código ser definido.

## Escopo

1. Tabela `erp_production_orders` (status `draft` | `cancelled`), com ficha, item, quantidade e unidade.
2. Trigger de consistência: ficha pertence ao item, tipo `recipe` ou `bill_of_materials`, ficha ativa, unidade igual à unidade de rendimento.
3. RLS: leitura por `stock.read` (ou `stock.manage`, `stock.count`, staff); escrita por `stock.manage`; sem DELETE.
4. View `erp_production_order_requirements` (security_invoker): necessidade de insumos por ordem em rascunho.

Fora deste gate: baixa de estoque (movimentos `production` / `consumption`), status `posted`, conversão automática de unidades, kits.

## Decisões tomadas sem intervenção (revisar)

- Rendimento: `erp_item_compositions.yield_quantity`. `erp_recipe_yields` (versionado) fica para gate futuro, para não haver duas fontes de verdade.
- Kits não geram ordem nesta versão.
- Fórmula: `linha.quantity * (ordem.quantity / ficha.yield_quantity) * (1 + linha.loss_percent / 100)`.
- Unidade da ordem obrigatoriamente igual à unidade de rendimento da ficha.

## Evidências

| Etapa | Resultado |
|---|---|
| Leitura prévia | `erp_item_compositions`, `erp_item_composition_lines`, `erp_recipe_yields`: 0 linhas. `erp_stock_movements`: 1 linha (`opening`). Tipos `production` e `consumption` já permitidos pelo check. |
| Preflight 0064 | 8/8 OK (1 INFO: fichas = 0) |
| Migration 0064 | Aplicada com sucesso no staging |
| Testes 0064 | 9 cenários (A–I) passaram; transação com ROLLBACK |
| Pós-aplicação | RLS ativo; 3 policies; trigger presente; view com security_invoker; anon sem acesso; sem DELETE para authenticated; zero linhas residuais |

Testes cobertos: cálculo de necessidade (0,5 e 0,55 com perda de 10%), ficha de outro item, unidade divergente, quantidade zero, ficha inativa, chave de idempotência repetida, cancelamento sem data, ordem cancelada fora da visão.

## Pendências

- Teste 0062 D (falha de entrega sem motivo) continua sem execução: staging não tem comandas. Só a definição do check foi confirmada.
- 0063 (`age_restricted`, `fumigeno`, `erp_discount_authorizations`, seed de `erp_tenant_settings`): ainda não criada.
- `STATUS-MESTRE-DESENVOLVIMENTO.md` (.md e .html): não atualizado nesta sessão.
- Projeto `claude/PDV-mapeamento-erp.md`: não atualizado com as seis decisões.
- Commit: não feito (aguarda "commit local"). Push: não feito (aguarda "push").

## Arquivos

- `supabase/migrations/0064_erp_ordens_producao_ficha.sql`
- `supabase/preflight/0064_erp_ordens_producao_ficha_preflight.sql`
- `supabase/tests/0064_erp_ordens_producao_ficha.test.sql`
- `supabase/rollback/0064_erp_ordens_producao_ficha.rollback.sql`
- `RELATORIO-0064-ordens-producao-ficha.md` (este arquivo)
