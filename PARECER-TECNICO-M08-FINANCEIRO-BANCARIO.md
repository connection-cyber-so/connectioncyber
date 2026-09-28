# Parecer técnico M08 — Financeiro e bancário

## 1. Decisão

O M08 será um livro financeiro multiempresa no mesmo núcleo aprovado. Contas a receber, contas a pagar, parcelas, liquidações, bancos, cartões, cheques e boletos terão `tenant_id` obrigatório, RLS e chaves compostas. Nenhum saldo financeiro será armazenado como campo livremente editável.

Título é a obrigação; parcela define vencimento; liquidação registra transferência de valor; estorno gera contrapartida. O estado financeiro será sempre derivado desses eventos, preservando o histórico.

## 2. Fluxo gráfico

```mermaid
flowchart LR
    ORIG[Venda, compra, OS ou lançamento] --> E[Título financeiro]
    E --> I1[Parcela 1]
    E --> I2[Parcela N]
    I1 --> S[Liquidação]
    S --> A[Conta financeira]
    A --> BM[Movimento bancário/importado]
    BM --> R[Conciliação]
    R --> OK[Correspondência confirmada]
    X[Estorno] --> S2[Liquidação compensatória]
    S2 --> A
```

## 3. Modelo físico proposto

| Domínio | Entidades | Responsabilidade |
|---|---|---|
| Plano financeiro | `erp_financial_categories`, `erp_cost_centers` | classificação gerencial sem determinar regra fiscal |
| Contas | `erp_financial_accounts` | caixa, banco, carteira, clearing e outras contas de valor |
| Títulos | `erp_financial_entries` | obrigação a receber ou pagar, origem e contraparte |
| Parcelas | `erp_installments` | vencimento, principal e saldo derivado |
| Liquidações | `erp_settlements`, `erp_settlement_allocations` | recebimentos/pagamentos e rateio entre parcelas |
| Livro | `erp_financial_movements` | entradas, saídas, transferências, tarifas e contrapartidas |
| Bancos | `erp_bank_accounts`, `erp_bank_transactions` | dados bancários mínimos e extrato importado |
| Conciliação | `erp_bank_reconciliations`, `erp_bank_reconciliation_items` | correspondência auditável banco × livro |
| Cartões | `erp_card_receivables`, `erp_card_receivable_events` | agenda, taxa, antecipação e liquidação de adquirência |
| Cheques | `erp_checks`, `erp_check_events` | emissão/recebimento, custódia, depósito e devolução |
| Boletos | `erp_billing_slips`, `erp_billing_slip_events` | referência, vencimento e eventos; sem credencial bancária |

## 4. Estados

- título: `draft → open → partially_settled → settled | cancelled`;
- parcela: `open → partially_settled → settled | overdue | cancelled`;
- liquidação: `pending → confirmed → reversed | failed`;
- conciliação: `draft → processing → completed | cancelled`;
- recebível de cartão: `scheduled → available → settled | anticipated | disputed | cancelled`;
- cheque: `received | issued → held → deposited → cleared | returned | cancelled`;
- boleto: `draft → registered → pending → paid | overdue | cancelled | protested`.

Transições serão comandadas por serviços/RPCs. Interfaces não poderão marcar títulos como pagos diretamente.

## 5. Invariantes financeiras

1. valores usam `numeric(19,4)` e moeda ISO de três letras;
2. soma das parcelas deve coincidir com o valor do título;
3. soma das alocações deve coincidir com o valor líquido da liquidação;
4. liquidação confirmada gera movimentos financeiros balanceados;
5. transferência exige saída e entrada vinculadas pela mesma operação;
6. estorno referencia a operação original e produz contrapartida, sem exclusão;
7. saldo da parcela é `principal + juros + multa - desconto - liquidações confirmadas`;
8. datas de competência, emissão, vencimento e liquidação são conceitos separados;
9. toda postagem exige ator, origem e `idempotency_key` única por tenant;
10. moeda não pode ser alterada após abertura do título.

## 6. Integração com vendas e compras

- venda concluída no M07 poderá originar um título a receber quando não for totalmente liquidada à vista;
- pagamento capturado no M07 poderá originar liquidação, sem duplicar caixa ou banco;
- pedido de compra não gera obrigação; o evento financeiro será definido pelo recebimento/documento do fornecedor;
- devolução/estorno comercial gera ajuste financeiro por contrapartida;
- vínculos usam `source_type`, `source_id` e chave idempotente;
- lançamentos M08 não alteram venda, pagamento, recebimento ou movimento M06/M07 concluído.

## 7. Contas bancárias e segurança

- armazenar somente banco, agência, conta mascarada/necessária, tipo e titularidade;
- tokens, client secrets, certificados, senhas e credenciais Open Finance ficam em cofre externo;
- banco guarda apenas referência do segredo e metadados não sensíveis;
- importações de OFX/CNAB/API terão hash, origem, período, lote e idempotência;
- arquivos bancários originais não serão versionados no Git;
- PIX copia e cola, boleto e dados de cartão completos não serão persistidos em logs;
- dados de cartão serão limitados a bandeira, últimos quatro dígitos, adquirente e identificador externo.

## 8. Conciliação

A conciliação será explícita, não uma atualização de saldo. Cada item de extrato poderá ficar `unmatched`, ser associado a um movimento, dividido entre movimentos ou marcado como exceção justificada. Correspondências automáticas usarão valor, data, documento e referência, mas exigirão rastreabilidade e nível de confiança.

Reimportar o mesmo extrato não poderá duplicar transações. O hash da conta, data, valor, referência e origem comporá a identidade determinística quando o banco não fornecer ID estável.

## 9. Cartões, cheques e boletos

- cartões: separar pagamento da venda, agenda da adquirente e crédito efetivo no banco;
- taxas e antecipações geram movimentos próprios, nunca alteração silenciosa do valor bruto;
- chargeback/disputa gera evento e contrapartida;
- cheque mantém histórico de custódia e compensação;
- boleto mantém identificadores e eventos, mas registro/transmissão dependerá de integração bancária futura;
- emissão fiscal e regras tributárias continuam no M13.

## 10. Operações atômicas propostas

1. `erp_post_financial_entry`: valida e abre título/parcelas;
2. `erp_confirm_settlement`: bloqueia parcelas, valida saldo e posta liquidação/movimentos;
3. `erp_reverse_settlement`: cria contrapartida vinculada;
4. `erp_transfer_financial_balance`: posta saída e entrada inseparáveis;
5. `erp_complete_bank_reconciliation`: fecha lote após validar correspondências e diferenças.

Todas serão idempotentes, executarão com permissões explícitas e confirmarão tudo ou reverterão tudo.

## 11. Segurança e permissões

- `finance.read`, `finance.entry`, `finance.settle`, `finance.reverse`, `finance.adjust`;
- `treasury.read`, `treasury.manage`, `treasury.transfer`;
- `banking.read`, `banking.import`, `banking.reconcile`;
- `receivables.read/manage`, `payables.read/manage`;
- `anon` sem acesso e `authenticated` limitado por RLS;
- livros, liquidações confirmadas e conciliações concluídas sem `UPDATE`/`DELETE`;
- ajustes, estornos, transferências e conciliações exigem motivo e auditoria;
- ações de alto impacto deverão exigir MFA conforme M04.

## 12. Concorrência e idempotência

- locks por tenant/parcela impedem liquidação simultânea acima do saldo;
- locks por conta financeira impedem transferências inconsistentes;
- ordem de bloqueio será determinística para evitar deadlocks;
- ID bancário externo e hash de importação serão únicos por tenant/conta;
- webhook, arquivo e operação repetidos retornam o resultado existente;
- mesma chave com conteúdo diferente será recusada.

## 13. Relatórios derivados

- contas a receber/pagar por vencimento, contraparte e categoria;
- fluxo de caixa realizado e projetado;
- posição por conta financeira e estabelecimento;
- inadimplência e aging;
- taxas e agenda de cartões;
- cheques em custódia/devolvidos;
- boletos pendentes/pagos;
- itens bancários conciliados, pendentes e divergentes.

Nenhum relatório manterá saldo independente do livro de origem.

## 14. Limites do M08

- não define impostos, escrituração contábil oficial ou plano de contas contábil;
- não transmite boleto, PIX, CNAB ou Open Finance sem integração e credenciais futuras;
- não armazena segredo bancário, cartão completo ou arquivo real de cliente;
- fiscal permanece no M13;
- importação de legado permanece no M14;
- dados e contas reais somente entram no piloto M15 após segurança, backup e aceite.

## 15. Sequência determinística proposta

1. criar migration `0024`, preflight, rollback e testes SQL;
2. implementar RPCs de título, liquidação, estorno, transferência e conciliação;
3. criar serviços e telas de receber, pagar, tesouraria e bancos;
4. testar concorrência, idempotência, rateio, estorno e reconciliação;
5. validar dry-run e solicitar autorização exclusiva antes da aplicação remota.

## 16. Critérios de aceite

O M08 será aceito quando comprovar isolamento cross-tenant, parcelas reconciliadas com títulos, liquidações balanceadas, impossibilidade de pagamento duplicado, estorno por contrapartida, transferências inseparáveis, importação idempotente, conciliação rastreável, ausência de segredos e zero dados reais.
