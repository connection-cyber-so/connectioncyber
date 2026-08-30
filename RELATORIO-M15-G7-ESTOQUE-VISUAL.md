# M15-G7 — estoque visual integrado ao PDV

Data: 30/08/2026

## Entrega

- Tela visual de estoque com busca, saldo e destaque de estoque baixo.
- Entradas e saídas sintéticas com ledger da sessão.
- Bloqueio determinístico de saída acima do saldo.
- Atualização imediata da disponibilidade exibida no PDV.
- Estado exclusivamente em memória, sem rede ou persistência.

## Validação

- Node.js 22.23.2.
- 41/41 testes aprovados.
- TypeScript, ESLint e build Next.js aprovados.
- Entrada de 2 unidades: saldo alterado de 18 para 20.
- Saída de 25 unidades: bloqueada com saldo preservado em 20.
- PDV confirmou `SYN-001 · 20 disponíveis`.
- Celular 390 × 844: formulário visível e `scrollWidth=375`.

## Decisão

`M15_G7_INVENTORY_VISUAL_OK`. Supabase, Vercel e produção não acessados.
