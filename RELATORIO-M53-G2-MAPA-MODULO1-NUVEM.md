# RELATÓRIO M53-G2 — Mapa do módulo 1 (clientes, produtos, estoque) para o tenant Nuvem

**Data:** 06/11/2026
**Ambiente:** `connectioncyber-staging` (Supabase staging `ozvylnaipubrmaadikvk`)
**Tenant alvo:** Nuvem de Papel — `00000000-0000-0000-0000-000000000001` (M53-G1)
**Status do gate:** mapeamento concluído. Nenhuma escrita no banco. Nenhum código alterado.

## 1. Escopo e decisão de partida

- A base da Nuvem é de teste (confirmado pelo responsável). Não há migração de dado real.
- Este gate **redefine M53-G2**: de "migração de dados (somente inserts)" para "mapa + povoamento com dados fictícios em staging".
- Povoamento real, quando houver, exige gate próprio e aceite explícito.

## 2. Fontes usadas

- Origem: código-fonte do app Nuvem (`src/`) e migrations `supabase/migrations/0001–0031` do repositório `nuvem-de-papel`.
- Destino: `information_schema` e `pg_constraint` do staging ConnectionCyber, consultados por MCP.
- **Limitação:** o MCP não tem permissão no projeto Nuvem (`urlfwxeflxpdmmxkuuur`). O schema de origem é o das migrations, não o schema vivo. Confirmar contra o banco vivo antes do povoamento real.

## 3. Mapa de clientes

| Origem Nuvem (`customers`) | Destino ConnectionCyber | Observação |
|---|---|---|
| `id`, `tenant_id`, `created_at` | `erp_parties.id`, `tenant_id`, `created_at` | `kind = 'person'` (CHECK: person/organization) |
| `name` | `erp_parties.legal_name` | 2–180 caracteres |
| `documento` (11 ou 14 dígitos) | `erp_parties.tax_id` + `erp_party_documents` (`cpf`/`cnpj`) | `tax_id` aceita só dígitos |
| `ie` | `erp_parties.state_registration` | regex `^[A-Z0-9]{2,20}$` no ERP; validar formato |
| `email` | `erp_party_contacts` (`type = 'email'`) | |
| `telefone` | `erp_party_contacts` (`type = 'phone'`) | |
| `whatsapp` | `erp_party_contacts` (`type = 'whatsapp'`) | |
| `cep`, `uf` | `erp_party_addresses` (`postal_code`, `state_code`, `type = 'main'`) | `state_code` = `^[A-Z]{2}$` |
| papel cliente | `erp_party_roles` (`role = 'customer'`) | |
| `tier`, `points` | **sem destino** | fidelidade não existe no ERP; decidir em gate próprio |
| `limite_credito` | **sem destino** | pertence ao financeiro; decidir no módulo 8 |
| `nascimento` | **sem destino** | sem coluna em `erp_parties`; decidir se necessário |

## 4. Mapa de produtos

| Origem Nuvem | Destino ConnectionCyber | Observação |
|---|---|---|
| `catalog_items.sku` | `erp_catalog_items.code` | 1–64 caracteres |
| `catalog_items.name` | `erp_catalog_items.name` | 2–180 caracteres |
| `catalog_items.active` | `erp_catalog_items.status` | `true` → `active`; `false` → `inactive`; `draft` para rascunho |
| `catalog_items.category` | `erp_catalog_items.metadata` `{"categoria": ...}` | jsonb objeto; sem tabela de categoria no ERP |
| (sempre `product`) | `erp_catalog_items.kind = 'product'` | |
| `base_unit_id` | `erp_units` (`UN`, `CX`, `KG` ...) | criar unidades de teste antes |
| `item_prices` (canal `varejo`) | `erp_price_lists` (`channel = 'retail'`) + `erp_price_items` | lista por canal |
| `item_prices` (canal `atacado`) | `erp_price_lists` (`channel = 'wholesale'`) | **confirmar enum `sales_channel` do app** |
| `item_commercial_data.cost_price` | `erp_item_commercial_data.cost_price` | |
| `item_commercial_data.margin_percent` | `erp_item_commercial_data.margin_percent` | |
| `item_commercial_data.min_stock` | `erp_item_commercial_data.min_stock_quantity` | |
| `item_fiscal_data.ncm` | `erp_item_fiscal_data.ncm` | obrigatório |
| `item_fiscal_data.cst_csosn` | `erp_item_fiscal_data.tax_code` + `tax_code_kind` | decidir `kind` (CST ou CSOSN) |
| `item_fiscal_data.icms_rate` / `ipi_rate` | `erp_item_fiscal_data.icms_rate` / `ipi_rate` | obrigatórios |
| `item_fiscal_data.weight_kg` | `erp_item_fiscal_data.gross_weight` | |
| campos fiscais obrigatórios sem origem (`origin`, `icms_base_percent`, `fcp_rate`) | valores de teste | **validar com contador antes de uso real** |
| `item_supplier_data` | **sem destino direto** | vínculo produto-fornecedor fica para o módulo de compras |

## 5. Mapa de estoque

| Origem Nuvem | Destino ConnectionCyber | Observação |
|---|---|---|
| `item_stock.stock_on_hand` / `stock_available` | `erp_stock_movements` (tipo `opening`) somado por local | saldo é derivado de movimentos |
| `stock_movements.entrada` | `erp_stock_movements.type = 'purchase_receipt'` | |
| `stock_movements.ajuste` | `type = 'inventory_adjustment'` | |
| `stock_movements.devolucao` | `type = 'return'` | |
| `stock_movements.venda` | `type = 'sale'` | |
| `stock_movements.reserva` / `liberacao` | `erp_stock_reservations` | não são movimentos |
| local (loja) | `erp_stock_locations` (`kind = 'store'`) | exige `establishment_id` |

**Conflito de modelo a decidir:** existem dois modelos de estoque no staging.
- Modelo ERP: `erp_stock_locations` + `erp_stock_movements`. Recomendado para lojas.
- Modelo M54 (Centro Logístico): `locais` + `enderecos` + `saldos`. Já em uso no CD. `saldos.produto_id` aponta para o catálogo ainda sem FK.

Recomendação: lojas no modelo ERP; CD mantém M54 até um gate de unificação. Registrar a decisão antes do povoamento.

## 6. Dados fictícios propostos (ainda não gravados)

- Tenant: Nuvem (já existe).
- Estabelecimento: 1 loja de teste (`erp_establishments`, `code = 'NDP-LOJA-TESTE'`).
- Unidades: `UN`, `CX`, `KG`.
- Clientes: 15 pessoas (`legal_name` com prefixo `Cliente Teste NN`, e-mails `@teste.invalid`).
- Fornecedores: 3 organizações (`Fornecedor Teste NN`), papel `supplier`.
- Produtos: 25 itens de papelaria (`code = 'TST-0001'` a `'TST-0025'`), com `metadata.categoria`.
- Preços: listas `retail` e `wholesale` por item.
- Fiscal: NCM ilustrativo (ex.: `4820.10.00`), marcado como "validar com contador".
- Estoque: 1 movimento `opening` por produto na loja de teste.
- Marcador: todos os registros fictícios têm prefixo `TESTE`/`TST` para limpeza segura.

## 7. Riscos

1. Mapa baseado em migrations, não no banco vivo da Nuvem.
2. Dois modelos de estoque coexistindo.
3. Campos fiscais de teste podem ser confundidos com dado real se não forem marcados.
4. Fidelidade e crédito sem destino no ERP.

## 8. Próximo passo (aguarda aceite)

1. Confirmar enum `sales_channel` do app Nuvem.
2. Aceitar a decisão de modelo de estoque (lojas = ERP; CD = M54).
3. Autorizar o povoamento fictício em staging (escrita remota) com os dados da seção 6.
4. Depois do povoamento: atualizar `STATUS-MESTRE-DESENVOLVIMENTO.md` (.md e .html) e fazer o commit de checkpoint.
