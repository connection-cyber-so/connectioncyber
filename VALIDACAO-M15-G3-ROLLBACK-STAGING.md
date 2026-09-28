# M15-G3 — Validação transacional no Supabase staging

Data: 30/08/2026
Projeto autorizado: `ozvylnaipubrmaadikvk`

## Resultado

**APROVADO — ensaio executado com rollback e zero persistência.**

- vínculo confirmado antes da execução;
- migrations locais/remotas alinhadas de 0001 a 0031;
- dry-run sem migration, seed ou role pendente;
- preflight: `M15_G3_PREFLIGHT_OK`;
- pgTAP: plano de 30 asserções concluído até `ok 30`, sem diagnóstico de falha em `finish()`;
- pós-rollback: `M15_G3_ROLLBACK_CLEAN`;
- tenants sintéticos residuais: 0;
- contas sintéticas residuais: 0;
- documentos fiscais sintéticos residuais: 0;
- histórico remoto permaneceu em 0001–0031.

Produção não foi acessada. Nenhuma migration foi aplicada e nenhum dado real foi utilizado.
