# M15-G9 — financeiro visual integrado ao caixa

Data: 30/08/2026

## Entrega

- Contas a receber e pagar com criação, vencimento, filtros e status.
- Baixa financeira condicionada a caixa aberto.
- Pagamentos protegidos contra saldo insuficiente.
- Recebimentos e pagamentos refletidos automaticamente no ledger do caixa.
- Estado exclusivamente em memória, sem rede ou persistência.

## Validação

- Node.js 22.23.2.
- 51/51 testes aprovados.
- TypeScript, ESLint e build Next.js aprovados.
- Baixa com caixa fechado: bloqueada.
- Abertura do caixa: R$ 300,00.
- Pagamento FIN-002: R$ 210,00; saldo resultante R$ 90,00.
- Recebimento FIN-001: R$ 480,00; saldo resultante R$ 570,00.
- Celular 390 × 844: tela visível e `scrollWidth=375`.

## Decisão

`M15_G9_FINANCE_VISUAL_OK`. Supabase, Vercel, bancos, pagamentos e produção não acessados.
