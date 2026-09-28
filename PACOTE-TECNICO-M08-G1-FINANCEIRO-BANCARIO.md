# Pacote técnico M08-G1 — Financeiro e bancário

## Entrega local

- migration `0024_m08_finance_banking.sql` com 15 tabelas;
- 15 permissões de financeiro, tesouraria, bancos, receber e pagar;
- RPC de título com parcelamento determinístico;
- RPC de liquidação com lock e bloqueio de pagamento acima do saldo;
- RPC de transferência com duas pernas inseparáveis;
- preflight somente leitura, rollback protegido e 64 asserções SQL;
- telas `/financeiro` e `/bancos`.

## Segurança

- tenant revalidado em todas as operações;
- títulos, parcelas e movimentos recebem escrita somente pelas RPCs;
- livros, liquidações, extratos e conciliações sem exclusão para usuários;
- contas bancárias guardam somente dados mascarados e referência de segredo;
- tokens, senhas, certificados e arquivos reais permanecem fora do banco e Git;
- `anon` não recebe acesso.

## Integridade

- parcelas somam exatamente o principal, com diferença de arredondamento na última;
- alocações precisam coincidir com o líquido da liquidação;
- liquidações confirmadas não excedem o saldo da parcela;
- movimentos financeiros possuem idempotência por tenant;
- transferência cria saída e entrada com o mesmo grupo transacional;
- transações bancárias possuem ID externo/hash determinístico.

## Evidências

- testes Node: 9/9;
- TypeScript: aprovado;
- ESLint sem cache: aprovado;
- preflight remoto somente leitura: `M08_PREFLIGHT_OK`;
- dry-run remoto: somente `0024_m08_finance_banking.sql` pendente;
- nenhuma migration M08, conta, título ou transação criada remotamente.

## Resultado remoto

Em 27/08/2026, a `0024` foi validada integralmente em transação com rollback, aplicada exclusivamente no Supabase staging e confirmada no histórico remoto. As 64 asserções passaram, o dry-run final não encontrou migrations pendentes e permaneceram zeradas as tabelas de títulos, liquidações, movimentos, contas e transações bancárias. Produção, credenciais e dados reais não foram alterados.
