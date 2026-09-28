# M16-G6 — aplicação persistente da 0032 no staging

Data: 31/08/2026

Projeto autorizado: Supabase staging `ozvylnaipubrmaadikvk`

## Resultado

**Migration `0032` aplicada exclusivamente no staging e validada.**

## Controles executados

1. SHA-256 confirmado: `237485033a7484147315adeda8184b837298e55982c9741f86cd9e7418c7e3f3`;
2. histórico remoto terminava em `0031`;
3. preflight retornou `M16_G3_PREFLIGHT_OK`;
4. dry-run selecionou exclusivamente `0032`;
5. `supabase db push --linked` aplicou somente `0032_m16_tenant_capabilities.sql`;
6. pgTAP remoto aprovou 60/60 asserções;
7. fixtures dos testes foram revertidas por `ROLLBACK`;
8. verificação pós-aplicação confirmou RLS, RPCs e privilégios mínimos;
9. histórico local/remoto alinhado até `0032`;
10. dry-run final sem migrations pendentes.

## Estado de dados

- zero exceções de capacidade;
- zero tenants ou fixtures M16-G3;
- nenhuma conta criada;
- nenhum dado real inserido;
- nenhuma produção acessada.

## Marcador

`M16_G6_0032_STAGING_APPLIED_OK`

## Próxima etapa automática

M16-G7 — painel administrativo local de capacidades, planos e exceções, usando somente dados sintéticos até autorização posterior de integração.
