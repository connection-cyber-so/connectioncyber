# Pacote técnico M06-G1 — Preços, estoque e compras

## Entrega local

- migration `0022_m06_pricing_stock_purchasing.sql` com 15 tabelas;
- preflight somente leitura e rollback recusado quando existirem dados M06;
- 48 asserções SQL para objetos, RLS, grants, imutabilidade e constraints;
- oito permissões específicas de preços, estoque, inventário e compras;
- rota `/operacoes` com visão de listas, locais e pedidos;
- nenhuma conta, fixture, produto, saldo ou pedido criado.

## Garantias

- `tenant_id` obrigatório e FKs compostas;
- estabelecimento/localização como fronteira operacional;
- livro de movimentos sem `UPDATE` e `DELETE` para `authenticated`;
- idempotência obrigatória em movimento e recebimento;
- série limitada a quantidade absoluta igual a um;
- snapshots de pedido preservam código, descrição, unidade, preço e total;
- saldo continuará derivado de movimentos postados, sem coluna editável de saldo.

## Evidências

- `npm test`: 9/9;
- TypeScript: aprovado;
- ESLint sem cache: aprovado;
- preflight remoto somente leitura: `M06_PREFLIGHT_OK`;
- dry-run remoto: somente a migration `0022` pendente;
- Supabase remoto permanece com histórico até `0021`.

## Resultado remoto

Em 26/08/2026, a migration foi validada integralmente em transação com rollback, aplicada exclusivamente no Supabase staging e confirmada no histórico remoto. As 48 asserções passaram, o dry-run final não encontrou migrations pendentes e as tabelas de listas de preços, movimentos, pedidos e recebimentos permaneceram com zero registros. Produção, contas e dados reais não foram alterados.
