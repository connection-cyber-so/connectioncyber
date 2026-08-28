# Contrato canônico M13-G1 — fiscal

## Fronteira

O domínio recebe uma fotografia imutável da venda e produz documentos/eventos fiscais. Ele não consulta preço atual, não recalcula venda histórica, não captura pagamento e não entrega segredo ao navegador ou agente local.

## Comandos

| Comando | Entrada mínima | Idempotência | Saída |
|---|---|---|---|
| `fiscal.issue` | tenant, estabelecimento, ambiente, modelo, venda, snapshot, itens, totais | tenant+ambiente+modelo+série+número+operação | documento e estado |
| `fiscal.query` | tenant, ambiente, documento/provider ref | repetível | estado reconciliado |
| `fiscal.cancel` | documento autorizado, justificativa, ator AAL2 | documento+evento | evento de cancelamento |
| `fiscal.invalidateNumber` | modelo, série, intervalo, justificativa, ator AAL2 | intervalo+evento | protocolo/evento |
| `fiscal.enterContingency` | NFC-e, UF, regra vigente, motivo | documento+modo | evento append-only |

## Invariantes

1. Tenant e ambiente são derivados no servidor e conferidos em toda resposta/webhook.
2. Série/número são reservados transacionalmente; repetição retorna a operação existente.
3. `timeout` e `unknown` acionam consulta; nunca autorizam nova numeração automaticamente.
4. XML assinado, protocolo, hash e eventos são imutáveis; correções usam eventos.
5. Adaptadores convertem contrato canônico ↔ provedor; payload do fornecedor não contamina o domínio.
6. Webhook exige autenticidade, inbox durável, deduplicação e reconciliação por consulta.
7. O contrato transporta apenas `certificateRef` interno; PFX, senha, CSC, token e chave privada são proibidos.

## Estados

`draft → validated → queued → signing → signed → transmitting → authorized`

Saídas controladas: `rejected`, `denied`, `contingency_pending`, `cancelled`. Uma rejeição permite correção por novo comando conforme regra; denegação e autorização não são apagadas.

## Artefatos deste portão

- schemas JSON em `packages/fiscal-contract/contracts`;
- validação executável e kill switch de produção em `packages/fiscal-contract/src`;
- 24 testes sintéticos em `packages/fiscal-contract/tests`;
- sem XML fiscal, certificado, credencial, chamada externa ou dado real.
