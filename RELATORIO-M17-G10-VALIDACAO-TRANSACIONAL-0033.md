# M17-G10 — validação transacional remota da migration 0033

Data: 31/08/2026

Projeto autorizado: Supabase staging `ozvylnaipubrmaadikvk`

Resultado: aprovado com `ROLLBACK`; nenhuma aplicação persistente.

## Execução determinística

1. O histórico remoto confirmou migrations `0001–0032` e ausência da `0033`.
2. O primeiro preflight falhou fechado porque `pgcrypto.digest` está no schema `extensions`, não em `public`.
3. Migration, preflight e testes foram corrigidos localmente para `extensions.digest`; 168/168 testes locais passaram.
4. O preflight repetido retornou `M17_0033_PREFLIGHT_OK`.
5. O artefato transacional foi verificado com zero `COMMIT`, um `ROLLBACK` e plano de 96 asserções.
6. A execução retornou `M17_0033_TRANSACTION_96_OF_96_ROLLBACK`.
7. A prova final confirmou `0033` ausente do histórico, `erp_command_receipts` ausente e todas as dez funções da migration ausentes.

## Integridade

- SHA-256 da migration validada: `f20d6f908a7f8477e5a6dd96cc02b2634451943b9bac70839ba4aa686e848e26`.
- SHA-256 do artefato transacional descartável: `5e25e1477cf5e2e7fd1430293c80f132d3eca6057a28b1ec1c46642beb690a05`.
- Contas, fixtures e dados reais criados: zero.
- Produção acessada: não.
- Outras migrations aplicadas: zero.

Marcador: `M17_G10_0033_TRANSACTION_96_OF_96_ROLLBACK_OK`.

Próximo portão: aplicação persistente exclusiva da migration `0033` no mesmo staging e repetição das 96 asserções, mediante autorização separada.
