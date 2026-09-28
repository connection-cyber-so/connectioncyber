# M18-G18 — validação transacional remota da migration 0034

Data: 01/09/2026

Ambiente: Supabase staging `ozvylnaipubrmaadikvk`

Resultado: **APROVADA COM ROLLBACK; NÃO APLICADA PERSISTENTEMENTE**

## Evidências

- Histórico inicial remoto: migrations `0001–0033`; somente `0034` pendente.
- Dry-run remoto selecionou exclusivamente `0034_m18_protected_pilot_provisioning.sql`.
- Preflight: `M18_0034_PREFLIGHT_OK`.
- Pacote transacional validado primeiro no PostgreSQL local: 90/90 com rollback.
- Marcador remoto: `M18_0034_TRANSACTION_90_OF_90_ROLLBACK`.
- Pós-preflight: `M18_0034_PREFLIGHT_OK`.
- Histórico remoto final: `0034` ausente.
- SHA-256 do pacote gerado: `5E5E8662C282D3B245766436C339861ECEBA6E5FC76EE5CDE1B20DFBBB8F8F38`.
- SHA-256 do builder: `80F3944C8237878A18636BE99047BBC05203A26A57813CD1A6FED3D42F4B00D1`.

## Garantias

- Nenhum tenant, estabelecimento, identidade, membership, role, outbox ou compensação persistiu.
- Nenhuma conta Auth foi criada.
- Nenhuma outra migration foi executada.
- Produção não foi acessada.

## Próximo portão

M18-G19 — aplicação persistente exclusiva da migration `0034` no Supabase staging e repetição das 90 asserções. Exige autorização específica; ainda não autoriza criar o tenant ou usuário da Mania de Modas.
