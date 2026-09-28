# M14-G5 — Parecer final de prontidão da migration 0031

Data: 29/08/2026

Ambiente auditado: `F:\Projetos\connectioncyber-staging` e Supabase local

Migration: `0031_m14_import_ledger.sql`

SHA-256: `860234c17a87009892485679553b46c8f271df2b9180de8c434e3765d2a8db1c`

## Decisão

**APROVADA para preflight e validação transacional remota com `ROLLBACK`.**

A aprovação não autoriza aplicação persistente. A migration `0031` deve continuar bloqueada para `db push` ou registro no histórico remoto até um portão posterior e autorização específica.

## Auditoria independente

1. Escopo conferido contra o checkpoint `912bbbc`; a migration permaneceu sem alterações durante o M14-G5.
2. Concorrência serializada nas três RPCs idempotentes e na disputa item/finalização do lote.
3. Isolamento tenant-scoped preservado por FKs compostas, sete tabelas com RLS e políticas somente de leitura/auditoria.
4. Cinco RPCs `security definer`, `search_path` vazio, execução exclusiva de `service_role` e ausência de `import.execute`.
5. Estados, metadados e reconciliação operam em modo fail-closed; divergência permanece registrada como `blocked`.

## Evidências repetidas

- Testes Node: **41/41**.
- pgTAP independente: **96/96**, dentro de transação com `ROLLBACK`.
- Catálogo local: **7/7** tabelas com RLS e **5/5** funções `security definer`.
- Permissões M14: somente `import.audit` e `import.read`.
- Resíduos: zero manifestos, jobs, lotes, itens e reconciliações.
- `git diff --check`: aprovado nos arquivos do escopo.

## Procedimento remoto autorizado no próximo portão

1. Confirmar projeto Supabase staging `ozvylnaipubrmaadikvk` e impedir acesso à produção.
2. Executar preflight somente leitura e exigir `M14_0031_PREFLIGHT_OK`.
3. Confirmar que apenas a `0031` está pendente; abortar se houver outra migration selecionada.
4. Executar a `0031` em transação remota com `ROLLBACK` e repetir as 96 asserções.
5. Confirmar ausência da `0031` no histórico remoto e zero resíduos M14.

## Riscos residuais

- A validação local não substitui a prova transacional no PostgreSQL remoto.
- A aplicação persistente permanece proibida nesta etapa.
- Importação de fonte real, credenciais, backups e dados de clientes permanece fora do escopo.
