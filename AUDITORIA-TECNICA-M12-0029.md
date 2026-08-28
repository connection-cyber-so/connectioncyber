# Auditoria técnica — M12 / migration 0029

**Data:** 28/08/2026  
**Migration analisada:** `0029_m12_local_agent_peripherals.sql`  
**SHA-256:** `995d853cb82cb832769b9e6b5a0fc66e5651f4016f2766bd442b1d36a5ff5379`  
**Supabase alterado:** não  
**Produção acessada:** não

## Parecer

**Resultado: bloqueada para validação ou aplicação remota.** A base estrutural é adequada, mas o contrato de confiança do agente ainda não está completo no banco.

## Achados bloqueadores

### B01 — não existe ativação segura do agente — crítico

O pareamento gera um código, mas nenhuma RPC consome o código, valida expiração, registra `key_id`/chave pública e muda o agente de `pairing` para `active` de maneira atômica. A ativação dependeria de escrita direta com `service_role`, sem contrato auditável.

**Correção:** RPC de ativação exclusiva do broker, uso único do hash, chave pública validada, expiração e evento imutável.

### B02 — resultados do agente não possuem entrada assinada e anti-replay — crítico

Há comandos e tentativas, mas nenhuma rotina recebe confirmação/resultados verificando agente, nonce, assinatura, expiração, estado anterior e idempotência. O modelo G1 não está conectado ao schema G2.

**Correção:** função de ingestão restrita ao broker, com envelope verificado antes da chamada, transição de estado fechada e evento idempotente.

### B03 — vínculos de contexto estão incompletos — crítico

As FKs garantem o tenant, mas não asseguram que:

- o periférico do comando pertence ao mesmo agente;
- snapshot, reserva e operação pertencem ao mesmo estabelecimento do agente;
- operação pertence ao mesmo agente/estabelecimento do snapshot.

**Correção:** constraints compostas contendo tenant, estabelecimento, agente e objeto relacionado.

### B04 — cadeia offline não é garantida pelo banco — crítico

`previous_hash` é apenas texto válido. Não há referência à operação anterior nem obrigação de sequência/hash encadeados. Operações também aceitam qualquer `operation_type` e payload sem limite de tamanho.

**Correção:** referência composta opcional ao hash anterior, primeira operação explícita, tipos permitidos, limites e ingestão idempotente pelo broker.

### B05 — leitura RLS é excessiva — alto

`agent.read` consegue ler pairings, payloads de comandos, tentativas, eventos e operações offline. Código hash, auditoria e dados operacionais exigem permissões mais restritas.

**Correção:** políticas específicas: inventário com `agent.read`; pairings com `agent.manage`; comandos/eventos com `agent.audit`; offline com `offline.sync`/`agent.audit`.

### B06 — resolução offline sem MFA e invariantes financeiras — alto

`erp_resolve_offline_operation` aceita/rejeita operações com uma permissão simples, sem AAL2, trava transacional, idempotência ou obrigação de motivo para rejeição/revisão.

**Correção:** AAL2, advisory lock, chave idempotente, motivo obrigatório e evento/conflito de reconciliação.

### B07 — rollback e testes são insuficientes — alto

O rollback não bloqueia dados independentes em `erp_agent_versions` e `erp_agent_update_policies`. As 64 asserções verificam estrutura, mas não cobrem ativação, transições, segregação de leitura, contexto composto ou cadeia offline.

**Correção:** ampliar a proteção do rollback e substituir testes superficiais por testes negativos dos invariantes corrigidos.

## Achados médios

- `document_hash` não exige SHA-256.
- Pareamento não relaciona consistentemente `status` e `consumed_at`.
- Revogação não valida o tamanho da chave de idempotência.
- Estados finais de comandos não exigem `completed_at`.
- Versões, códigos, adaptadores, tipos de operação e textos não possuem limites suficientes.
- A política global de versões permite leitura por qualquer autenticado; é aceitável apenas se assinatura e metadados forem deliberadamente não sensíveis.

## Controles aprovados

- AAL2 já está presente em pareamento, revogação e enfileiramento.
- Nenhum segredo global é destinado ao agente.
- TTL, nonce e idempotência de comandos estão modelados.
- RLS está prevista em todas as tabelas.
- TEF não armazena PAN completo ou CVV.
- Simuladores falham fechado e passaram em `19/19`.

## Ordem de remediação

1. Implementar ativação e ingestão segura pelo broker.
2. Reforçar FKs compostas e cadeia offline.
3. Segregar RLS de leitura e endurecer resolução offline.
4. Corrigir checks, limites, rollback e preflight.
5. Ampliar pgTAP e repetir testes locais antes de qualquer portão remoto.
