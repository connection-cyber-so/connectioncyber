# M18-G4 — financeiro, fechamento de caixa e dashboard local

Data: 31/08/2026

## Resultado

- O crediário do PDV exige cliente e gera recebível derivado.
- A baixa financeira usa `financial.settle` e impede valor maior que o saldo.
- O fechamento usa `cash.close` e falha quando o valor contado diverge do esperado.
- O dashboard relê clientes, produtos, estoque, vendas, caixa e financeiro do estado sintético server-side.
- A reconciliação comprova `vendas = dinheiro + crediário`, sem estado otimista no navegador.

## Validação

- Plataforma: 62/62 testes.
- Contrato visual: 49/49 testes.
- TypeScript: aprovado.
- ESLint: aprovado.
- Build Next.js com Node.js 22: aprovado.

## Segurança e escopo

- Dados exclusivamente sintéticos e efêmeros.
- Nenhuma chamada ao Supabase, Vercel, GitHub ou produção.
- Nenhuma conta, venda, recebível ou movimentação real criada.
- Tenant sintético resolvido somente no servidor local.

Marcador: `M18_G4_FINANCE_CASH_DASHBOARD_LOCAL_OK`

Próximo gate: M18-G5 — auditoria local independente de segurança, isolamento, replay, concorrência e UX da jornada visual integrada.
