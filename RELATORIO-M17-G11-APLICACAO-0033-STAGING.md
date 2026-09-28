# M17-G11 — aplicação persistente da migration 0033 em staging

Data: 31/08/2026

Projeto: Supabase staging `ozvylnaipubrmaadikvk`

Resultado: aprovado.

## Execução

1. Vínculo e SHA-256 foram confirmados antes da alteração.
2. O dry-run selecionou exclusivamente `0033_m17_persistent_journey.sql`, sem seeds ou roles.
3. A migration `0033` foi aplicada e registrada no histórico remoto.
4. As 96 asserções pgTAP pós-aplicação passaram; o teste terminou com `ROLLBACK`.
5. A auditoria final confirmou RLS ativo, dez funções esperadas e zero receipts.

## Segurança e escopo

- SHA-256 aplicado: `f20d6f908a7f8477e5a6dd96cc02b2634451943b9bac70839ba4aa686e848e26`.
- Histórico remoto: `0033/0033`.
- Funções persistidas: 10.
- Execuções de comandos concedidas a `anon`: 0.
- Helpers concedidos a `authenticated`: 0.
- Contas, fixtures, receipts e dados reais criados: 0.
- Outras migrations, seeds ou roles alteradas: 0.
- Produção acessada: não.

Marcador: `M17_G11_0033_STAGING_96_OF_96_OK`.

Próxima etapa automática: M17-G12 — encerramento da jornada persistente e definição técnica do próximo módulo cronológico, sem alteração remota.
