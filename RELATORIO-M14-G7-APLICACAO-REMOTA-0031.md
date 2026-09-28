# M14-G7 — Aplicação remota persistente da migration 0031

Data: 29/08/2026

Supabase staging: `ozvylnaipubrmaadikvk`

SHA-256: `860234c17a87009892485679553b46c8f271df2b9180de8c434e3765d2a8db1c`

## Resultado

**Migration 0031 aplicada e validada exclusivamente no staging.**

- Preflight de vínculo e histórico confirmou somente a `0031` pendente.
- Dry-run selecionou exclusivamente `0031_m14_import_ledger.sql`.
- Aplicação persistente concluída pelo fluxo oficial de migrations.
- Pós-aplicação fail-closed: `M14_0031_POSTAPPLY_96_OF_96_ROLLBACK`.
- Auditoria: `M14_0031_POSTAPPLY_AUDIT_OK`.
- Catálogo: sete tabelas com RLS, cinco RPCs `security definer` e somente `import.read`/`import.audit`.
- Contagens: zero manifestos, jobs, lotes, itens e reconciliações.
- Histórico remoto alinhado até `0031`.
- Dry-run final: banco remoto atualizado, sem migrations pendentes.

Uma leitura paralela do histórico apresentou falha transitória de autenticação; a repetição isolada foi concluída com sucesso e confirmou `0031/0031`.

Produção não foi acessada e nenhum dado real, fonte, backup ou credencial foi criado ou processado.
