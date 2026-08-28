# Pacote técnico M12-G2 — agente local e periféricos

**Data:** 28/08/2026  
**Estado:** implementação local concluída  
**Migration:** `0029_m12_local_agent_peripherals.sql`  
**SHA-256:** `995d853cb82cb832769b9e6b5a0fc66e5651f4016f2766bd442b1d36a5ff5379`  
**Supabase remoto alterado:** não  
**Produção acessada:** não

## Entregas

- 12 tabelas para agentes, pareamentos, periféricos, comandos, tentativas, eventos, snapshots, sequências, operações offline, conflitos e atualização.
- Cinco permissões funcionais separadas.
- Quatro RPCs `SECURITY DEFINER` para pareamento, revogação, comandos e resolução offline.
- AAL2 obrigatório para pareamento, revogação e comandos de periféricos.
- RLS e ausência de escrita direta por `authenticated`.
- TTL máximo de cinco minutos, nonce único e idempotência dos comandos.
- Rejeição de segredos em configurações, comandos, eventos e operações offline.
- Preflight, rollback de laboratório vazio e 64 asserções pgTAP.
- Simuladores determinísticos de impressão, balança, gaveta e TEF.

## Evidências locais

- Protocolo e simuladores: `19/19` testes.
- Sintaxe dos módulos Node: aprovada.
- `git diff --check`: aprovado.
- Hardware real utilizado: nenhum.
- Credenciais ou dados reais: nenhum.

## Limite atual

A migration ainda não foi executada em PostgreSQL. O ambiente Supabase local não está disponível e nenhuma validação remota foi autorizada. O próximo portão deve começar por auditoria técnica local da `0029`; somente após aprovação será solicitada autorização para transação remota com `ROLLBACK`.
