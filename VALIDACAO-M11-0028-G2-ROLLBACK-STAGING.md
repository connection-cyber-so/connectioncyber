# Validação transacional M11 0028 — Supabase staging

**Data:** 28/08/2026  
**Projeto:** `ozvylnaipubrmaadikvk`  
**Ambiente:** staging  
**Aplicação persistente:** não  
**Produção acessada:** não

## Resultado

- Branch confirmada: `staging`.
- Projeto vinculado confirmado: `ozvylnaipubrmaadikvk`.
- SHA-256 autorizado antes da validação: `a40b13977f6a46247cdc72e1804d7e8b0efe258ac508cb467eb19f07074d213f`.
- Histórico inicial: migrations `0001`–`0027`; `0028` ausente.
- Dry-run: selecionou exclusivamente `0028_m11_support_remote_access.sql`.
- Preflight remoto: `M11_PREFLIGHT_OK`.
- Migration e testes executados em uma única transação.
- pgTAP: `87/87`.
- Encerramento obrigatório: `ROLLBACK`.

## Auditoria posterior ao rollback

- Migration `0028` no histórico remoto: não.
- Tabelas principais M11 persistentes: zero.
- Permissões `support.*` e `remote.*` persistentes: zero.
- Produção: não acessada.
- Contas, tickets, consentimentos, grants, sessões e dados reais: não criados.

## Próximo portão

A migration `0028` está tecnicamente validada, mas continua não aplicada. A aplicação persistente exclusiva no Supabase staging exige nova autorização explícita.
