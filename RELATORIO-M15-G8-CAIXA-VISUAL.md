# M15-G8 — caixa visual integrado às vendas

Data: 30/08/2026

## Entrega

- Abertura de caixa com fundo inicial sintético.
- Entradas e saídas avulsas com proteção contra saldo negativo.
- Vendas concluídas no PDV lançadas automaticamente no ledger da sessão.
- PDV bloqueado enquanto o caixa estiver fechado.
- Fechamento somente quando o saldo contado coincide com o saldo calculado.
- Estado exclusivamente em memória, sem rede ou persistência.

## Validação

- Node.js 22.23.2.
- 46/46 testes aprovados.
- TypeScript, ESLint e build Next.js aprovados.
- Venda bloqueada com caixa fechado.
- Abertura: R$ 100,00.
- Venda Pix: R$ 59,90.
- Saldo calculado: R$ 159,90.
- Fechamento divergente em R$ 150,00 bloqueado.
- Fechamento exato em R$ 159,90 aprovado.
- Celular 390 × 844: tela visível e `scrollWidth=375`.

## Decisão

`M15_G8_CASH_VISUAL_OK`. Supabase, Vercel, pagamentos e produção não acessados.
