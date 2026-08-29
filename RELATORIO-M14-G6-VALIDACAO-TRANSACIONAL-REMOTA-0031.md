# M14-G6 — Validação transacional remota da migration 0031

Data: 29/08/2026

Projeto Supabase: staging `ozvylnaipubrmaadikvk`

Migration: `0031_m14_import_ledger.sql`

SHA-256: `860234c17a87009892485679553b46c8f271df2b9180de8c434e3765d2a8db1c`

## Resultado

**APROVADA em transação remota com `ROLLBACK`; não aplicada persistentemente.**

- Vínculo conferido: `ozvylnaipubrmaadikvk`.
- Dry-run selecionou exclusivamente `0031_m14_import_ledger.sql`.
- Preflight inicial: `M14_0031_PREFLIGHT_OK`.
- Validação fail-closed: `M14_0031_TRANSACTION_96_OF_96_ROLLBACK`.
- Histórico final: remoto permanece em `0030`; `0031` ausente.
- Preflight final: `M14_0031_PREFLIGHT_OK`, comprovando zero resíduos.
- Nenhum dado real, fonte, backup ou credencial foi criado ou processado.
- Produção não foi acessada.

## Decisão

A migration `0031` está tecnicamente pronta para um portão separado de aplicação persistente exclusivamente no Supabase staging. Esta validação não autoriza `db push`, registro manual no histórico ou acesso à produção.
