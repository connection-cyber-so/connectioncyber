# M17-G1 — contrato canônico da jornada persistente

Data: 31/08/2026

## Entrega

- Pacote executável `@connectioncyber/persistent-journey-contract` criado.
- Sete comandos canônicos: cadastro, catálogo, entrada de estoque, abertura de caixa, venda, baixa financeira e fechamento de caixa.
- Seis máquinas de estado: pessoa, item, estoque, caixa, venda e recebível.
- Catálogo de erros separa código interno de resposta pública segura, status HTTP e possibilidade de repetição.
- Chave idempotente deriva do tenant resolvido no servidor, tipo do comando e identificador da requisição.
- Campos de autoridade enviados pelo navegador são recusados, inclusive quando aninhados.

## Controles comprovados

- tenant e ator precisam ser sintéticos e resolvidos pelo servidor;
- membership ativa e capacidade correspondente são obrigatórias;
- replay idêntico não duplica efeitos;
- mesma chave com payload diferente falha com conflito;
- quantidades e valores não positivos são recusados;
- venda sem caixa ou saldo de estoque falha fechado;
- baixa acumulada não supera o recebível;
- falha injetada restaura todo o snapshot e não registra evento parcial;
- payloads reais e segredos são recusados.

## Evidências

- Testes do contrato: 25/25 aprovados com Node.js 22.23.2.
- Simulador: sete comandos, sete eventos e sete registros idempotentes.
- Resultado reconciliado: uma pessoa, um item, estoque 8, uma venda de 2.000 centavos, recebível integralmente liquidado e caixa fechado.
- Regressão da plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Persistência, rede, Supabase e produção: não acessados.

Marcador: `M17_G1_PERSISTENT_JOURNEY_CONTRACT_OK`

Próxima etapa automática: M17-G2 — camada server-side de resolução de tenant, membership, capacidades e autorização de comandos, usando dublês locais.
