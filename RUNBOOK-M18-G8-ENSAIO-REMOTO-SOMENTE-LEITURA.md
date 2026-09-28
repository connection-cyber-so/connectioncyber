# Runbook M18-G8 — ensaio remoto somente leitura

Estado: preparado localmente; execução remota bloqueada.

## Escopo permitido após autorização específica

1. Confirmar branch `staging` e vínculo exclusivo com `ozvylnaipubrmaadikvk`.
2. Confirmar migrations locais/remotas até `0033`, sem pendências selecionadas.
3. Executar apenas `supabase/preflight/m18_g8_visual_read_only_preflight.sql`.
4. Exigir o marcador `M18_G8_READ_ONLY_PREFLIGHT_OK`.
5. Encerrar sem criar sessão, conta, fixture, receipt ou qualquer dado.

## Bloqueios obrigatórios

- Não executar RPC de comando.
- Não usar `db push`, migration, seed ou SQL mutável.
- Não ativar o adaptador nas telas.
- Não acessar produção.
- Interromper se o project ref não for exatamente `ozvylnaipubrmaadikvk`.

## Critério de aceite

O preflight deve confirmar sete RPCs, relações/colunas esperadas, RLS ativo, `SELECT` para `authenticated`, ausência de `SELECT` para `anon`, `EXECUTE` para `authenticated` e ausência de `EXECUTE` para `anon`.
