# M14-G2 — migration local 0031

Data: 29/08/2026
Ambiente: staging local
Decisão: **APROVADO NO LABORATÓRIO POSTGRESQL LOCAL**

## Entrega

- migration `0031_m14_import_ledger.sql`;
- sete tabelas tenant-scoped;
- cinco RPCs exclusivamente `service_role`;
- RLS e leitura autenticada por permissões;
- preflight, rollback e 80 asserções pgTAP;
- testes estáticos do pacote de importação.

## Controles

- nenhum backup, caminho, credencial ou payload bruto no ledger;
- hashes SHA-256 para origem, mapeamento, lote, item e evidência;
- conflito de idempotência em manifesto, job, lote e item é fail-closed;
- reconciliação de quantidade e centavos sob bloqueio de linha;
- escrita direta por `authenticated` e acesso de `anon` revogados;
- produção e Supabase remoto não acessados.

## Evidências executadas

- testes Node/estáticos: `37/37`;
- simulador: `M14_G1_IMPORT_SIMULATOR_OK`;
- preflight: `M14_0031_PREFLIGHT_OK`;
- pgTAP inicial após correção: `80/80`;
- rollback, zero resíduos, reconstrução e pgTAP final: `80/80`;
- SHA-256 da migration: `ab297ff5046350d9fdc7f14dee2200137dc9080ff91245b2074439551148d74f`;
- `git diff --check`: aprovado;
- migration aplicada: somente no banco local descartável;
- dados criados: `false`.

## Correção durante o laboratório

O primeiro pgTAP retornou `79/80` porque o PostgreSQL truncou o nome automático de uma constraint longa. A constraint recebeu o nome explícito `uq_import_mapping_context`; após rollback e reconstrução, as duas passagens ficaram em `80/80`.

## Próxima ação

Auditoria técnica final local da `0031`. Somente depois poderá ser solicitado um portão separado para validação transacional remota com `ROLLBACK`; aplicação persistente continuará proibida.
