# M18-G9 — preflight remoto somente leitura

Data: 01/09/2026

## Alvo confirmado

- Branch local: `staging`.
- Supabase staging vinculado: `ozvylnaipubrmaadikvk`.
- Commit de preparação: `b4c809e`.
- SQL executado: `supabase/preflight/m18_g8_visual_read_only_preflight.sql`.
- SHA-256: `B834D673A87B5BB41E54CFA046FF2D1E53A5240E2050788CE89DD071344A6A55`.

## Resultado remoto

- Comando executado: consulta do arquivo preflight via vínculo staging.
- Exit code: `0`.
- Marcador recebido: `M18_G8_READ_ONLY_PREFLIGHT_OK`.
- Transação definida como somente leitura e encerrada com `ROLLBACK`.

## Escopo preservado

- Nenhuma RPC de comando executada.
- Nenhuma migration aplicada.
- Nenhuma conta, sessão, receipt, fixture ou dado criado/alterado.
- Adaptador persistente não ativado nas telas.
- Produção não acessada.

Marcador: `M18_G9_REMOTE_READ_ONLY_PREFLIGHT_OK`

Próxima etapa automática local: M18-G10 — normalização canônica dos read models persistentes para os formatos visuais, usando somente dublês e sem novo acesso remoto.
