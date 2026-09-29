# RELATÓRIO M15-G12 — Materialização de entidades

Data: 29/09/2026
Executável: `scripts/m15-materialize-entities.mjs` (reusa `--config` do M14-G9 e o adaptador
`packages/import-contract/src/nfe-adapter.mjs`, agora expondo `unitPrice` cru para não perder
precisão de preço unitário com 4 casas).
Ambiente: Supabase staging `ozvylnaipubrmaadikvk` (único autorizado para dados reais).
Dado real: SQLs e resumos apenas em `%TEMP%\connectioncyber-m15\` — nada de CNPJ/CPF/chave
em repositório, relatório ou log.

## 1. O que foi materializado

| Entidade | Rose Variedades | Casa de Bolos | CSC Distribuidora | Total |
|---|---|---|---|---|
| `erp_sales` (vendas) | 1.455 | 50 | 6 | **1.511** |
| `erp_sale_items` (itens) | 1.795 | 207 | 9 | **2.011** |
| `erp_sale_payments` (pagamentos) | — | — | — | **1.511** |
| `erp_catalog_items` (produtos) | 791 | 72 | 9 | **872** |
| `erp_parties` (partes com doc) | 1 | 2 | 0 | **3** |
| Seeds `erp_units` / `erp_payment_methods` | 3 unid. / 5 métodos por tenant | idem | idem | 24 linhas |

Seeds estruturais por tenant (idempotentes por id derivado de `sha256(tenant|code)`):
unidades `UN`/`KG`/`CX` e métodos `DIN`/`PIX`/`CRE`/`DEB`/`OUT` (mapeamento `tPag`: 01→DIN,
03→CRE, 04→DEB, 15→PIX, demais→OUT).

## 2. Reconciliação (ledger × materializado)

Query independente fora da transação de carga:

| Métrica | Ledger (M14-G9) | Materializado (M15-G12) | OK? |
|---|---|---|---|
| Vendas (`domain='sales'`) | 1.511 | 1.511 | ✓ |
| Valor total (centavos) | 4.993.268 (R$ 49.932,68) | 4.993.268 | ✓ |
| Produtos (`domain='products'`) | 872 | 872 | ✓ |
| Partes com documento | 3 (6 no ledger menos 3 anônimas) | 3 | ✓ |

Todos os batches do ledger permanecem `reconciled`. A verificação também roda **dentro** do
próprio script (`M15_MAT_SUMMARY`): `vendas == vendas_ledger`, `valor_cents == ledger_cents`
e `catálogo == plano`, falhando o gate em qualquer divergência.

## 3. Decisões técnicas

1. **Sem migration nova** — `erp_parties`, `erp_catalog_items`, `erp_sales`, `erp_sale_items`,
   `erp_sale_payments`, `erp_units` e `erp_payment_methods` já existiam (0031+); o gate é
   puro povoamento, sem mudança de schema.
2. **Idempotência por id determinístico** — `uuidFromSha256(sha256(tenant|domínio|chave))`
   + `ON CONFLICT (id) DO UPDATE`; re-execução reproduz exatamente o mesmo estado.
3. **Dedupe por chave** — a fonte tem 56 duplicatas em pastas; o plano deduplica por chave
   antes de gerar SQL (duas linhas com o mesmo id no mesmo `INSERT` derrubam o
   `ON CONFLICT DO UPDATE`, erro `21000` observado e corrigido).
4. **`erp_sale_payments`** exige `UNIQUE NULLS NOT DISTINCT (tenant_id, provider, external_id)`
   — pagamentos gravados com `provider='nfe_xml'` e `external_id='<chave>-p<idx>'`;
   `status='captured'` com `captured_at` da emissão (default `pending` se sem data).
5. **Venda importada entra `status='completed'`** com `completed_at=dhEmi` (constraint exige
   `completed_at` não nulo quando não é `draft`); `customer_id` só quando o destinatário tem
   CPF/CNPJ (3 de 1.511 notas — NFC-e de varejo não declara documento; 1.508 ficam sem
   vínculo, como no ledger que guarda hash anônimo).
6. **Itens sem código ou quantidade ≤ 0** são pulados (contador `skippedItems`, 0 no lote);
   `unit_price` usa o valor cru do XML (4 casas) e `line_total` usa `vProd` em centavos.
7. **Categoria fiscal ignora estoque** — `kind='product'`, `track_inventory=false` (constraint
   proíbe rastrear estoque em `service`/`fee`/`voucher`; estoque é escopo do M15-G13).

## 4. Erros encontrados e corrigidos durante a execução

| Erro | Causa | Correção |
|---|---|---|
| `23505` em `erp_sale_payments` | unique `(tenant_id, provider, external_id)` não distingue NULL | preencher `provider`/`external_id` |
| `21000` `ON CONFLICT DO UPDATE cannot affect row a second time` | duplicatas da fonte gerando ids repetidos no mesmo comando | dedupe por chave no plano |
| CLI `UnexpectedArgument` em query posicional | `supabase db query --linked` só aceita `-f` | query via arquivo temporário |

## 5. Evidências

- Resumos por execução: `%TEMP%\connectioncyber-m15\materialize-summary-*.json` e
  `mat-<tenant>-*.sql` (histórico completo do SQL executado).
- Verificação independente (contagens + soma em centavos) reproduzível por qualquer
  consulta direta a `erp_sales`/`erp_import_items` no staging.
- Testes do adaptador: **60/60** (`node --test packages/import-contract/tests/`).

## 6. Próxima ação

**M15-G13** — catálogo/estoque reais por tenant (com `track_inventory` e saldos) +
conferência de domínio/deploy (alvo `66.33.60.130` da Mania divergente de `76.76.21.x`).
