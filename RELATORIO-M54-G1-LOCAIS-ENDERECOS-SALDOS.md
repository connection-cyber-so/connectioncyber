# RELATÓRIO M54-G1 — locais, endereços e saldos do Centro Logístico

Data: 06/11/2026 · Ambiente: staging `ozvylnaipubrmaadikvk` · Produção: intocada

## Escopo
- Migration aditiva `supabase/migrations/0055_cd_locais_enderecos_saldos.sql`: `locais` (loja | cd), `enderecos` (galpão/salão, rua, box, tipo_uso) e `saldos` (qtd e reservado por produto × endereço).
- RLS somente SELECT (membership ou staff); escrita fechada até o gate de RPC.
- Fora de escopo: catálogo de produtos (sem FK em `saldos.produto_id`), transferências, pedidos_cd, planos e capacidades (M54-G2/G3), dados FICTICIO.

## Evidência
| Etapa | Resultado |
|---|---|
| Preflight (`supabase/preflight/0055_..._preflight.sql`) | limpo: sem conflito, dependências e tenant Nuvem presentes |
| Teste (`supabase/tests/0055_..._test.sql`) | 8/8 com ROLLBACK |
| Rollback com dado | aborta e mantém as tabelas (validado localmente) |
| Rollback vazio + reaplicação | OK (localmente) |
| Staging pós-apply | 3 tabelas com RLS, 1 policy de SELECT cada, contagens 0 |
| Teste no staging | 8/8 com ROLLBACK; contagem zero depois |

## Correção aplicada nesta rodada
- O rollback 0055 não tinha `ON_ERROR_STOP`: se a checagem de dado falhasse, os `DROP` seguintes continuavam. Corrigido com `\set ON_ERROR_STOP on` e tudo em uma transação.

## Pendências
1. `saldos.produto_id` sem FK até existir catálogo de produtos.
2. Seed com dados FICTICIO fica para o M54-G4.

## Próxima ação
M54-G2 — planos e capacidades (`cd.armazenagem`, `cd.expedicao`, `site.loja`).
