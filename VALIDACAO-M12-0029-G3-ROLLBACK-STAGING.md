# Validação transacional M12 0029 — Supabase staging

**Data:** 28/08/2026  
**Projeto:** `ozvylnaipubrmaadikvk`  
**Ambiente:** staging  
**Aplicação persistente:** não  
**Produção acessada:** não

## Resultado

- Branch: `staging`.
- Projeto vinculado: `ozvylnaipubrmaadikvk`.
- Histórico inicial: migrations `0001`–`0028`; `0029` ausente.
- Dry-run: selecionou exclusivamente `0029_m12_local_agent_peripherals.sql`.
- Preflight remoto: `M12_PREFLIGHT_OK`.
- Migration e pgTAP executados na mesma transação.
- Resultado: `84/84`.
- Encerramento: `ROLLBACK`.

## Auditoria posterior

- Histórico remoto `0029`: ausente.
- Tabelas M12 principais persistentes: zero.
- Permissões M12 persistentes: zero.
- Agentes, periféricos, comandos e operações offline: zero.
- Dados reais criados: nenhum.
- Produção: não acessada.

## Próximo portão

A migration `0029` está validada transacionalmente, mas continua não aplicada. A aplicação persistente exclusiva no Supabase staging exige autorização separada e repetição das 84 asserções.
