# Pacote técnico M07-G1 — Vendas, orçamento e PDV

## Entrega local

- migration `0023_m07_sales_pos.sql` com 14 tabelas;
- preflight somente leitura e rollback protegido para laboratório vazio;
- 52 asserções SQL de estrutura, RLS, grants, imutabilidade, RPCs e idempotência;
- 13 permissões específicas de vendas, pagamentos e caixa;
- RPC idempotente de abertura de sessão de caixa;
- RPC de fechamento atômico de venda;
- telas `/vendas` e `/pdv`, sem habilitar operações reais antes da migration.

## Fechamento seguro

A função de fechamento bloqueia a venda, valida estado e idempotência, recalcula totais, exige lista de preços vigente ou permissão excepcional de desconto, confirma pagamentos capturados, exige localização para itens controlados e bloqueia saldo disponível negativo. Os locks são adquiridos em ordem determinística por localização/item/variante. Venda, baixa de estoque e movimento de caixa são confirmados ou revertidos juntos.

## Garantias

- tenant derivado e revalidado no servidor;
- documentos concluídos sem `UPDATE`/`DELETE` para usuários;
- movimentos de caixa e pagamentos capturados imutáveis;
- IDs externos e chaves idempotentes únicos por tenant;
- dinheiro exige sessão de caixa e permite troco somente em método compatível;
- checkout e Mercado Pago do site permanecem separados do ERP;
- fiscal, financeiro, offline e periféricos permanecem fora do M07.

## Evidências

- testes Node: 9/9;
- TypeScript: aprovado;
- ESLint sem cache: aprovado;
- preflight remoto somente leitura: `M07_PREFLIGHT_OK`;
- dry-run remoto: somente `0023_m07_sales_pos.sql` pendente;
- nenhum objeto M07, conta, venda, pagamento ou dado real criado.

## Resultado remoto

Em 27/08/2026, a migration foi validada integralmente em transação com rollback, aplicada exclusivamente no Supabase staging e confirmada no histórico remoto. As 52 asserções passaram, o dry-run final não encontrou migrations pendentes e permaneceram zeradas as tabelas de orçamentos, vendas, pagamentos, sessões e movimentos de caixa. Produção, contas e dados reais não foram alterados.
