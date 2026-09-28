# @connectioncyber/device-protocol

Contrato executável do M12-G1 para comunicação entre backend e agente local.

## Garantias atuais

- envelope `1.0` com tenant, estabelecimento e agente explícitos;
- assinatura Ed25519 sobre JSON canônico;
- TTL máximo de cinco minutos e tolerância futura de 30 segundos;
- nonce protegido contra replay;
- chave de idempotência obrigatória;
- rejeição recursiva de campos de segredo;
- cadeia SHA-256 para operações offline;
- nenhuma rede, banco, hardware ou credencial nos testes.

## Estados normativos

Comando: `queued -> delivered -> acknowledged -> executing -> succeeded|failed|expired|cancelled`.

Operação offline: `local_pending -> syncing -> accepted|rejected|manual_review`.

Agente: `pairing -> active -> suspended|revoked`; um agente revogado não retorna a `active` sem novo pareamento e nova chave.

## Regras de compatibilidade

- Mudança compatível adiciona tipo ou campo opcional e mantém `1.x`.
- Mudança que altera significado, assinatura ou campo obrigatório exige nova versão principal.
- Tipo desconhecido é recusado; não existe fallback permissivo.
- O consumidor deve verificar assinatura, tenant, agente, expiração e replay antes de interpretar `payload`.

## Uso local

```powershell
Set-Location -LiteralPath "F:\Projetos\connectioncyber-staging\packages\device-protocol"
npm test
```
