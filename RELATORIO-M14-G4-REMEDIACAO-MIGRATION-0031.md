# M14-G4 — Remediação local da migration 0031

Data: 29/08/2026

Ambiente: `F:\Projetos\connectioncyber-staging`, Supabase local

Decisão: **aprovada localmente; aplicação remota continua bloqueada**

## Sete bloqueios remediados

1. As RPCs idempotentes de manifesto, job e lote agora serializam concorrência com `pg_advisory_xact_lock`.
2. Inclusão de item e finalização bloqueiam a mesma linha do lote; itens não entram após o fechamento.
3. Rejeições e reconciliações usam chaves estrangeiras compostas com tenant, lote e job coerentes.
4. Manifesto, job, lote, item e finalização aplicam transições de estado fail-closed.
5. Metadados e regras usam allowlists de chaves e bloqueiam padrões de segredo, DSN e caminho local nos valores.
6. Divergência de reconciliação persiste estado `blocked` e retorna resultado JSONB sem rollback acidental.
7. A permissão insegura `import.execute` foi removida; permanecem apenas leitura e auditoria sob RLS.

## Evidências

- Testes Node: **41/41**.
- pgTAP ciclo 1: **96/96**.
- Rollback e preflight repetido: `M14_0031_PREFLIGHT_OK`.
- Reaplicação local e pgTAP ciclo 2: **96/96**.
- Sete tabelas com RLS; cinco RPCs exclusivas de `service_role`.
- Zero manifestos, jobs, itens ou reconciliações.
- SHA-256 da migration: `860234c17a87009892485679553b46c8f271df2b9180de8c434e3765d2a8db1c`.

## Limites preservados

Nenhuma fonte, credencial ou dado real foi usado. Supabase remoto, Vercel, GitHub `main` e produção não foram acessados ou alterados.

## Próxima etapa

M14-G5: auditoria final independente da migration remediada e parecer de prontidão para validação transacional remota com `ROLLBACK`.
