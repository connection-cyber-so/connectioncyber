# Pacote técnico CTR-0027-G1 — Busca híbrida corrigida

Data: 27/08/2026

## Resultado

A migration `0027_m05_ctr_hybrid_search.sql` foi remediada localmente e permanece não aplicada. O catálogo funciona sem provedor de embeddings: itens novos gravam metadados vetoriais nulos e a RPC executa fallback lexical quando `query_embedding` é `NULL`.

## Correções concluídas

- removido o vetor placeholder `new Array(1536).fill(0.01)`;
- removida a escrita de embedding do formulário autenticado;
- pgvector fixado no schema `extensions` e objetos qualificados;
- HNSW parcial apenas para embeddings não nulos;
- FTS inclui código, nome e descrição;
- RPC exige permissão de catálogo e limita `match_count`/texto;
- combinação semântica/lexical usa Reciprocal Rank Fusion;
- metadados de modelo, hash e atualização são obrigatórios quando houver vetor;
- inserts/updates autenticados não podem gravar colunas vetoriais;
- adicionado fallback lexical server-side;
- criados preflight, rollback protegido e 36 asserções pgTAP.

## Arquivos

- `supabase/migrations/0027_m05_ctr_hybrid_search.sql`;
- `supabase/preflight/0027_m05_ctr_hybrid_search_preflight.sql`;
- `supabase/rollback/0027_m05_ctr_hybrid_search.rollback.sql`;
- `supabase/tests/0027_m05_ctr_hybrid_search.test.sql`;
- `apps/platform/src/features/catalog/actions.ts`;
- `apps/platform/src/features/catalog/service.ts`.

## Validações locais

- TypeScript aprovado;
- ESLint aprovado;
- testes Node: 9/9;
- `git diff --check` deve ser executado antes do checkpoint;
- suíte SQL preparada, mas não executada contra banco remoto.

## Decisão pendente

Nenhum provedor de embeddings foi escolhido e nenhum conteúdo será transmitido externamente. A busca lexical é o modo seguro padrão. Provedor, modelo, dimensão, privacidade, retenção e custo exigem decisão separada antes de habilitar geração semântica real.

## Bloqueio remoto

É proibido aplicar a migration `0027` ou a M11 `0028` sem novo portão explícito. Antes disso, a `0027` deve passar por preflight/dry-run e 36 asserções em ambiente autorizado.
