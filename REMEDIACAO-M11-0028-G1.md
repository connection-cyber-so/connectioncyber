# Remediação local — M11 / migration 0028

**Ambiente:** `connectioncyber-staging`  
**Supabase alterado:** não  
**Produção acessada:** não  
**Estado:** pronta para preflight e validação transacional remota mediante autorização

## Controles implementados

- AAL2 obrigatório para emissão e revogação de acesso remoto, inclusive para staff.
- Políticas RLS separadas por `support.manage`, `support.assign`, `support.sla`, `remote.request`, `remote.connect` e `remote.audit`.
- Consentimento pendente sem escrita direta posterior; decisão somente pela RPC auditada `erp_decide_remote_consent`.
- Validade máxima do consentimento concedido limitada a 24 horas.
- Leitura de grants, eventos e artefatos restrita a auditoria remota.
- Integridade composta entre anexo/mensagem/ticket e grant/consentimento/dispositivo/ticket.
- Validação de escopo, audience, motivo e chaves de idempotência.
- Rollback atualizado para remover a nova RPC em laboratório vazio.

## Evidências locais

- Testes da aplicação: `9/9`.
- TypeScript: aprovado.
- ESLint: aprovado.
- pgTAP preparado: `87` asserções.
- `git diff --check`: aprovado.

## Limite da validação

O Supabase local não respondeu no limite de 30 segundos. A migration ainda precisa ser validada no staging dentro de uma transação com `ROLLBACK` antes de qualquer aplicação persistente.
