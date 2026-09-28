# M16-G4 — auditoria e remediação local da migration 0032

Data: 30/08/2026

## Parecer

**A migration está pronta para uma futura validação transacional com rollback, mas não está autorizada para aplicação remota.**

## Bloqueios encontrados e corrigidos

| Bloqueio | Risco | Remediação |
|---|---|---|
| `service_role` recebia `GRANT ALL` | mutação ou exclusão direta do contrato | privilégio reduzido para `SELECT` e `INSERT` estritamente necessários |
| referência de aprovação aceitava texto livre | identidade ou justificativa sensível no banco | formato obrigatório `approval:sha256:<64 hex>` |
| revogação dependia de atualização direta | alteração sem fluxo validado | RPC broker-only, idempotente e limitada a exceção ativa |
| resolver não era exercitado pelo pgTAP | precedência poderia divergir do contrato | cenários `deny`, `allow`, default deny e pós-revogação adicionados |
| pgTAP não verificava privilégios do broker | excesso de autoridade poderia regressar | asserções negativas para update, delete e catálogo incluídas |

## Controles confirmados

- três tabelas com RLS;
- escrita de entitlements e exceções somente pelo broker;
- nenhuma mutação de catálogo pelo `service_role`;
- `deny` prevalece sobre `allow` e entitlement;
- exceção revogada deixa imediatamente de habilitar capacidade;
- ausência de configuração permanece `disabled`;
- nenhum dado real, conta, documento fiscal ou segredo nos fixtures;
- ensaio transacional termina em `ROLLBACK`.

## Evidência

- SHA-256 final após compatibilização com a fundação 0016: `237485033a7484147315adeda8184b837298e55982c9741f86cd9e7418c7e3f3`;
- 54/54 testes locais aprovados;
- 60 asserções pgTAP preparadas;
- banco e serviços remotos não acessados.

## Próximo portão

M16-G5 — preflight remoto somente leitura e validação transacional da `0032` com `ROLLBACK`. Exige autorização específica; não aplicar persistentemente.

## Marcador

`M16_G4_MIGRATION_0032_AUDITED_READY`

## Normalização durante M16-G5

O primeiro preflight remoto revelou que catálogo e entitlements já eram canônicos desde a `0016`. A `0032` foi corrigida para estender `erp_capability_catalog` e `erp_tenant_capabilities`, criando somente a tabela de exceções e as RPCs controladas. Nenhum objeto existente foi substituído.
