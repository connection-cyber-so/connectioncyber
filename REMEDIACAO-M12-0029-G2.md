# Remediação M12-G2 — migration 0029

**Data:** 28/08/2026  
**SHA-256 remediado:** `78b25f9123682db5729653c106bf4e0881873aadbd1d32799c466e8023ef3bd5`  
**Supabase alterado:** não  
**Produção acessada:** não

## Correções concluídas

- Ativação atômica do agente por código de uso único, chave pública e evento auditável.
- Ativação, resultados e ingestão assinada restritos ao `service_role` do broker; `authenticated` não executa essas RPCs.
- Evidência de assinatura armazenada por hash do envelope, `key_id` e horário de verificação.
- Transições de comandos fechadas e idempotentes.
- Contexto composto entre tenant, estabelecimento, agente, periférico e snapshot.
- Cadeia offline com referência ao hash anterior, sequência e tipos permitidos.
- Payloads limitados e campos de segredo recusados.
- Resolução offline com AAL2, lock, idempotência, motivo e evento.
- RLS segregada por gestão, auditoria, periféricos e sincronização offline.
- Rollback protegido também contra versões e políticas de atualização existentes.
- pgTAP ampliado de 64 para 84 asserções.

## Evidências locais

- Protocolo e simuladores: `19/19`.
- Sintaxe Node: aprovada.
- `git diff --check`: aprovado.
- Migration executada em banco: não.
- Hardware, credenciais e dados reais: não utilizados.

## Próximo portão

Executar uma segunda auditoria estática curta e, se aprovada, solicitar autorização para preflight e validação transacional remota com `ROLLBACK` e 84 asserções. A aplicação persistente continuará em portão separado.
