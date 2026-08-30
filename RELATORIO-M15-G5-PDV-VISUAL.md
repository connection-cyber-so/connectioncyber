# M15-G5 — Primeiro fluxo visual completo de PDV

Data: 30/08/2026

## Resultado

**APROVADO — venda sintética completa executada no navegador.**

## Fluxo entregue

- abertura pelo botão “Nova venda” e pelo módulo “Vendas e PDV”;
- busca local por produto ou código;
- catálogo com seis produtos sintéticos e saldo disponível;
- carrinho, incremento, decremento e remoção;
- quantidade limitada ao estoque;
- desconto limitado ao subtotal e total nunca negativo;
- pagamento por Pix, dinheiro ou cartão;
- finalização bloqueada sem itens;
- comprovante sintético sem emissão fiscal ou persistência.

## Validação

- portal: 31/31 testes;
- TypeScript, ESLint e build: aprovados;
- venda visual: 3 itens, desconto de R$ 20, cartão e total de R$ 419,70;
- comprovante: `SYNTHETIC-SALE-002`;
- celular 390 × 844: seis produtos visíveis e zero overflow da página;
- cliente Supabase, `fetch` e transmissão: ausentes do componente.

## Limites

Todo estado existe somente na memória do navegador. Atualizar a página elimina a venda. Nenhum dado, pagamento ou documento fiscal é criado.
