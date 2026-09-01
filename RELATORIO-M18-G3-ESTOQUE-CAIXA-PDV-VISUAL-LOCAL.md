# M18-G3 — estoque, caixa e PDV na fronteira visual local

Data: 31/08/2026

Resultado: aprovado localmente.

## Entrega

- `/operacoes` executa `inventory.receive` e relê saldo/movimentos pelo broker M18.
- `/pdv` executa `cash.open` e `sale.complete` pelo mesmo cliente server-side.
- Produto, estoque, caixa e vendas compartilham estado sintético efêmero da sessão local.
- Preço sintético de R$ 100,00 por unidade é atribuído e derivado no servidor local.
- A venda prepara um rascunho server-side e envia à fronteira apenas `saleId` e chave idempotente.
- Venda em dinheiro atualiza estoque e esperado de caixa como uma única operação do dublê.

## Controles

1. Entrada exige produto ativo com controle de estoque e quantidade positiva.
2. Uma segunda abertura de caixa falha fechado.
3. Venda exige estoque suficiente.
4. Venda em dinheiro exige caixa aberto.
5. Formulário não envia preço, total, saldo, esperado de caixa ou tenant.
6. Crediário permanece bloqueado até o M18-G4 financeiro.
7. Páginas operacionais não importam Supabase e declaram claramente o modo sintético.

## Evidências

- 52/52 testes da plataforma aprovados, incluindo 12 testes M18-G3.
- 49/49 testes do contrato visual aprovados.
- TypeScript, ESLint e build Next.js aprovados.
- Rotas `/operacoes` e `/pdv` compiladas como páginas dinâmicas.
- Supabase, banco, Vercel, GitHub remoto e produção não acessados.
- Dados fiscais, contas e dados reais criados: zero.

Marcador: `M18_G3_INVENTORY_CASH_POS_VISUAL_LOCAL_OK`.

Próxima etapa automática: **M18-G4 — integrar financeiro, fechamento de caixa, dashboard e reconciliação visual por releitura local sintética.**
