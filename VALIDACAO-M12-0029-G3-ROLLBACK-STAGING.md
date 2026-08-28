# Validação transacional M12 0029 — Supabase staging

**Data:** 28/08/2026  
**Projeto:** `ozvylnaipubrmaadikvk`  
**Aplicação persistente:** não  
**Produção acessada:** não

## Resultado

- Branch: `staging`.
- SHA-256: `78b25f9123682db5729653c106bf4e0881873aadbd1d32799c466e8023ef3bd5`.
- Dry-run: exclusivamente `0029_m12_local_agent_peripherals.sql`.
- Preflight: `M12_PREFLIGHT_OK`.
- Migration e pgTAP executados na mesma transação.
- Asserções: `84/84`.
- Encerramento: `ROLLBACK`.

## Auditoria posterior

- Histórico remoto `0029`: ausente.
- Tabelas principais M12 persistentes: zero.
- Permissões M12 persistentes: zero.
- Agentes, periféricos, comandos e operações offline: zero.
- Produção: não acessada.

## Próximo portão

A migration `0029` está validada tecnicamente, mas permanece não aplicada. A aplicação persistente exclusiva no Supabase staging exige autorização própria e nova execução das 84 asserções.
