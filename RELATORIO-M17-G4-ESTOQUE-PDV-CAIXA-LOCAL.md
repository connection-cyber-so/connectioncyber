# M17-G4 — estoque, PDV e caixa em unidade local idempotente

Data: 31/08/2026

## Entrega

- Aplicação operacional conecta entrada de estoque, abertura de caixa, venda e fechamento à autorização server-side.
- Unidade de trabalho local reúne estoque, movimentos, vendas, caixa e inbox idempotente.
- Venda multilinha consulta item e preço no catálogo do tenant.
- Total e snapshots de preço são derivados no servidor; valor sugerido pelo cliente não é autoridade.
- Estoque, venda e valor esperado do caixa mudam atomicamente.

## Controles comprovados

- entrada exige item rastreável e quantidade positiva;
- venda exige caixa aberto e estoque suficiente;
- replay não repete baixa, venda ou movimento;
- payload divergente com a mesma chave é recusado;
- falha após a baixa restaura estoque, venda, caixa, movimentos e inbox;
- fechamento divergente é bloqueado e preserva caixa aberto;
- fechamento conferido conclui o caixa;
- outro tenant não lê estoque, caixa, vendas ou movimentos.

## Evidências

- Testes do pacote: 89/89 aprovados com Node.js 22.23.2.
- Simulação: `M17_G4_LOCAL_OPERATIONS_OK`.
- Catálogo: preço unitário de 1.000 centavos.
- Venda: duas unidades, total server-side de 2.000 centavos; sugestão do cliente ignorada.
- Estoque final: 8 unidades; caixa final: 7.000 centavos e estado fechado.
- Plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Persistência remota, Supabase, rede e produção não acessados.

## Limite desta etapa

A unidade operacional usa somente repositórios locais. Interface e adaptadores Supabase permanecem desconectados até os gates de integração posteriores.

Marcador: `M17_G4_LOCAL_OPERATIONS_OK`

Próxima etapa automática: M17-G5 — integrar financeiro derivado e reconciliação ponta a ponta em memória, usando dados sintéticos.
