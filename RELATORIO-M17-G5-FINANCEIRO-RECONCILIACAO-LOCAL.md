# M17-G5 — financeiro derivado e reconciliação local

Data: 31/08/2026

## Entrega

- Vendas em dinheiro geram lançamento liquidado e atualizam o caixa físico.
- Vendas a prazo geram recebível aberto sem inflar o caixa.
- Baixas parciais e integrais passam pela autorização server-side e inbox idempotente.
- Reconciliação compara vendas brutas, caixa registrado, recebíveis, liquidações e saldo aberto por tenant.
- Todo o estado permanece em memória e usa somente identificadores sintéticos.

## Controles comprovados

- valor financeiro deriva do total server-side da venda;
- recebível desconhecido, já liquidado ou originado de venda em dinheiro é recusado;
- baixa acima do saldo falha com `RECEIVABLE_OVERPAYMENT`;
- replay não duplica liquidação e payload divergente conflita;
- falha injetada restaura lançamento, inbox e eventos;
- projeção é idempotente e lançamentos órfãos ou divergentes falham fechado;
- outro tenant não enxerga lançamentos financeiros.

## Evidências

- Pacote: 108/108 testes aprovados com Node.js 22.23.2.
- Simulação: `M17_G5_LOCAL_FINANCE_RECONCILIATION_OK`.
- Vendas: 3.000 centavos; caixa: 2.000; recebíveis: 1.000; baixa: 1.000; saldo aberto: zero.
- Caixa fechado e conferido em 7.000 centavos, incluindo fundo de 5.000.
- Plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Supabase, rede, Vercel, GitHub remoto e produção não acessados.

## Limite desta etapa

O financeiro ainda usa repositório local. Persistência Supabase, migrations e dados reais permanecem bloqueados para gates posteriores.

Marcador: `M17_G5_LOCAL_FINANCE_RECONCILIATION_OK`

Próxima etapa automática: M17-G6 — auditoria local independente de segurança, concorrência, idempotência e rollback da jornada integrada.
