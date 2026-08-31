# M16-G1 — contrato canônico de capacidades

Data: 30/08/2026

## Entrega

- catálogo único de capacidades operacionais;
- blueprints sintéticos MEI, ME e LTDA;
- exceções `allow` e `deny` com justificativa, aprovador e expiração;
- resolução determinística com hash de auditoria;
- comportamento fail-closed para versão, perfil e capacidade desconhecidos;
- simulador sem banco, rede ou persistência.

## Decisões

- perfil jurídico fornece apenas uma configuração inicial;
- autorização efetiva futura continuará server-side e tenant-scoped;
- exceções não serão implementadas por CNPJ, nome de cliente ou condicionais espalhadas;
- o contrato local não altera plano comercial, banco ou ambiente remoto.

## Validação

- Node.js 22.23.2;
- 20/20 testes aprovados;
- `deny` prevalece sobre `allow`, independentemente da ordem;
- exceção expirada não altera o blueprint;
- hash canônico muda quando o contrato muda;
- simulador confirmou MEI, ME e LTDA sem acesso remoto.

## Marcador

`M16_G1_CAPABILITY_CONTRACT_OK`
