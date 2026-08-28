# Validação CTR 0027 — Supabase staging

**Data:** 27/08/2026  
**Projeto:** `ozvylnaipubrmaadikvk`  
**Ambiente:** staging  
**Produção acessada:** não  
**Migration 0028 aplicada:** não

## Resultado

- Preflight: `CTR_0027_PREFLIGHT_OK`.
- Dry-run: selecionou somente `0028`; por isso `supabase db push` não foi usado.
- Estado legado detectado: histórico `0027` presente, pgvector em `public`, RPC sem verificação RBAC e índice HNSW sem filtro parcial.
- Validação integral da remediação: `36/36` dentro de transação com `ROLLBACK`.
- Aplicação: execução direta e exclusiva de `0027_m05_ctr_hybrid_search.sql`.
- Revalidação remota: `36/36`.
- pgvector: schema `extensions`.
- RPC: assinatura com `extensions.vector`, `SECURITY INVOKER` e RBAC.
- Índices: HNSW parcial e GIN presentes.
- RLS do catálogo: ativa.
- Embeddings e fixtures criados: zero.
- Histórico remoto: `0027` presente; `0028` ausente.

## Remediações incorporadas

- Relocação determinística do pgvector legado para `extensions` quando suportada.
- Reconstrução do HNSW legado com filtro `embedding IS NOT NULL`.
- Preflight idempotente para histórico remoto existente.
- Asserção RRF tornada robusta à formatação retornada pelo PostgreSQL.

## Próximo portão

A migration `0028_m11_support_remote_access.sql` permanece bloqueada e exige autorização exclusiva própria antes de qualquer validação ou aplicação remota.
