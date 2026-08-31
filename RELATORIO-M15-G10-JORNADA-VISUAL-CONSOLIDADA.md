# M15-G10 — jornada visual consolidada

Data: 30/08/2026

## Entrega

- Dashboard conectado ao estado compartilhado da sessão demonstrativa.
- Indicadores derivados de vendas, estoque, caixa e títulos financeiros.
- Títulos financeiros preservados durante a navegação entre módulos.
- Atalhos e alertas do painel abrem diretamente o fluxo correspondente.
- Estado exclusivamente em memória, sem rede ou persistência.

## Validação

- Node.js 22.23.2.
- 56/56 testes aprovados.
- TypeScript, ESLint e build Next.js aprovados.
- Venda concluída atualiza vendas e caixa da sessão.
- Ajuste de estoque atualiza a quantidade de itens críticos.
- Baixa financeira atualiza contas abertas e saldo do caixa.
- Navegação mantém produtos, clientes, caixa e títulos da sessão.

## Decisão

`M15_G10_CONSOLIDATED_JOURNEY_OK`. Supabase, Vercel, bancos, pagamentos, serviços fiscais e produção não acessados.
