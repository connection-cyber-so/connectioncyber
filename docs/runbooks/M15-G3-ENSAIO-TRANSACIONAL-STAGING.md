# M15-G3 — Ensaio transacional descartável no staging

## Estado

Executado no staging após autorização específica. Resultado: 30 asserções concluídas e `M15_G3_ROLLBACK_CLEAN` com zero resíduos. Qualquer repetição exige nova autorização.

## Ordem determinística

1. confirmar o project ref de staging e proibir produção;
2. executar `supabase/preflight/m15_g3_synthetic_journey_preflight.sql` em modo somente leitura;
3. exigir o marcador `M15_G3_PREFLIGHT_OK`;
4. executar `supabase/tests/m15_g3_synthetic_journey.rollback.sql` em uma única sessão;
5. exigir 30/30 asserções, `ROLLBACK` e ausência dos slugs `m15-g3-synthetic-%`.

## Critérios de parada

- project ref diferente do staging autorizado;
- migration 0016, 0018, 0021–0024, 0030 ou 0031 ausente;
- fixture residual encontrada;
- qualquer asserção diferente de `ok`;
- criação de conta, documento fiscal ou persistência depois do rollback.

O script não aplica migration, não usa seed global e não acessa produção.
