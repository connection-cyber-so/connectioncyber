# M18-G17 — auditoria e validação local da migration 0034

Data: 01/09/2026

Resultado: **APROVADA LOCALMENTE PARA VALIDAÇÃO TRANSACIONAL REMOTA**

## Auditoria e remediação

- Reconstrução completa do PostgreSQL local pelas migrations `0001–0034`.
- Corrigido `INSERT` de steps com quantidade desigual de valores.
- Corrigidos `step_key` iniciados por número, incompatíveis com a constraint canônica.
- Hash final da `0034`: `0551FD5EF16B2BCD3F530EBED65FE1CBFAB0EA3D651899F6EBD5167610F48251`.

## Evidências

- pgTAP estrutural: 72/72.
- pgTAP adversarial sintético: 18/18.
- Testes estáticos: 15/15.
- Preparação, replay, conflito idempotente, segredo, campo desconhecido, caller não autorizado, capacidades, owner/MFA e outbox exercitados.
- Todas as fixtures foram executadas em transação com `ROLLBACK`.
- Pós-validação: zero tenant sintético, zero outbox e zero compensações.
- Supabase remoto e produção não acessados.

## Próximo portão

M18-G18 — preflight remoto e validação transacional exclusiva da migration `0034` no Supabase staging, com `ROLLBACK` e 90 asserções. Exige autorização específica; aplicação persistente continuará bloqueada.
