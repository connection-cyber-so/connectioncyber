# M17-G8 — migration local 0033

Data: 31/08/2026

## Entrega

- Migration local `0033_m17_persistent_journey.sql`.
- Inbox `erp_command_receipts`, único por tenant, comando e request.
- Três helpers internos e sete RPCs versionadas para a jornada M17.
- Preflight determinístico, rollback destrutivo controlado e plano pgTAP com 90 asserções.
- Nenhuma aplicação ou validação remota executada.

## Controles implementados

- payload JSONB é recalculado com SHA-256 no banco antes do claim;
- replay exige request e hash idênticos;
- request concorrente é serializado por advisory lock;
- permissão e capacidade são verificadas antes da escrita;
- receipt e alterações de domínio compartilham a mesma transação;
- helpers não são executáveis por `authenticated`;
- `anon` não executa RPCs e não lê o inbox;
- RLS habilitada e acesso direto ao inbox revogado;
- caixa, venda e liquidação usam locks de agregado;
- qualquer erro reverte receipt e efeitos do domínio.

## Artefatos

- Migration: `supabase/migrations/0033_m17_persistent_journey.sql`.
- Preflight: `supabase/preflight/0033_m17_persistent_journey_preflight.sql`.
- Rollback: `supabase/rollback/0033_m17_persistent_journey_rollback.sql`.
- pgTAP: `supabase/tests/0033_m17_persistent_journey.test.sql`.
- SHA-256 final da migration: `17f7fc7e740d6f11cdfdba86a81c44fc9d057b3a4bec6f5d1800c9daf635284b`.

## Evidências locais

- 163/163 testes Node.js aprovados com Node.js 22.23.2.
- 22 verificações estáticas específicas da 0033 aprovadas.
- Plano pgTAP: 90 asserções, encerrado com `ROLLBACK`.
- Plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- Docker está instalado, mas `psql` e Supabase CLI não estavam disponíveis neste ambiente; o pgTAP foi preparado e conferido estaticamente, ainda não executado contra PostgreSQL.
- Supabase, rede, Vercel, GitHub remoto e produção não acessados.

## Parecer

A `0033` está pronta para auditoria SQL local independente. Ainda não está autorizada para validação ou aplicação remota. O próximo gate deve revisar assinaturas, privilégios, compatibilidade com a baseline, concorrência e rollback antes de solicitar qualquer acesso ao staging.

Marcador: `M17_G8_MIGRATION_0033_LOCAL_READY`

Próxima etapa automática: M17-G9 — auditoria técnica local independente e remediação da migration `0033`, mantendo remoto bloqueado.
