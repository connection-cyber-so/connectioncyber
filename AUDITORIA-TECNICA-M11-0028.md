# Auditoria técnica — M11 / migration 0028

**Ambiente analisado:** checkout `staging`  
**Migration:** `0028_m11_support_remote_access.sql`  
**SHA-256 analisado:** `47e77ddff58377d31c2e777ceed54578a4c56e3cd77b9bc6109ce41b8c425d3`  
**Supabase alterado:** não  
**Produção acessada:** não

## Parecer

**Resultado: bloqueada para aplicação remota.** A estrutura geral é viável, mas a migration ainda não atende ao nível de segurança necessário para consentimento e acesso remoto.

## Achados bloqueadores

### B01 — bypass de MFA para staff — crítico

As RPCs `erp_issue_remote_access_grant` e `erp_revoke_remote_access` aceitam `is_platform_staff()` como alternativa completa a `has_permission_at_aal(..., 'aal2')`. Assim, uma sessão de staff sem AAL2 pode emitir ou revogar acesso remoto.

**Correção obrigatória:** exigir AAL2 tanto para usuários do tenant quanto para staff da plataforma.

### B02 — políticas de INSERT concedem permissões cruzadas — crítico

Uma única expressão é reutilizada em filas, SLA, tickets, mensagens, dispositivos e consentimentos. Qualquer usuário com `support.create`, por exemplo, pode inserir registros em estruturas administrativas ou de consentimento que não pertencem ao seu papel funcional.

**Correção obrigatória:** políticas específicas por domínio e permissão: `support.manage`, `support.assign`, `support.sla` e `remote.request`.

### B03 — consentimento remoto mutável diretamente — crítico

`authenticated` recebe `UPDATE` em `erp_remote_consents`. Um usuário com `support.manage` ou `remote.request` pode transformar diretamente um registro pendente em `granted`, além de modificar escopo e validade, sem uma RPC de decisão e sem evento imutável.

**Correção obrigatória:** revogar escrita direta; decidir/revogar consentimento por RPC auditada e idempotente.

### B04 — leitura excessiva de dados remotos — alto

A política genérica de SELECT permite que `support.read` consulte grants, sessões, eventos e artefatos remotos. Metadados de acesso remoto devem exigir `remote.audit` ou participação operacional estritamente definida.

**Correção obrigatória:** separar políticas de atendimento das políticas de acesso remoto.

### B05 — integridade relacional incompleta — alto

O banco garante o mesmo tenant, mas não garante que `message_id` pertença ao mesmo ticket do anexo nem que o consentimento pertença ao mesmo ticket e dispositivo do grant em todas as vias de escrita.

**Correção obrigatória:** chaves compostas que preservem ticket, dispositivo e consentimento como uma unidade consistente.

### B06 — testes não exercitam os riscos principais — alto

As 76 asserções verificam existência, RLS, privilégios gerais e constraints, mas não comprovam MFA para staff, segregação entre permissões, imutabilidade do consentimento, leitura restrita de dados remotos ou coerência relacional composta.

**Correção obrigatória:** substituir verificações superficiais e ampliar os testes de autorização negativa antes da validação remota.

## Achados não bloqueadores

- O rollback existe, mas seu nome correto é `0028_m11_support_remote_access.rollback.sql`.
- Tokens são armazenados apenas como SHA-256 e o valor bruto é devolvido somente na primeira emissão idempotente.
- Grants expiram em dez minutos e exigem ticket elegível, dispositivo ativo e consentimento válido.
- Eventos rejeitam chaves comuns de segredo; a lista deve continuar evoluindo com o gateway escolhido.
- Buckets e políticas do Supabase Storage ainda precisam de pacote próprio antes de anexos ou gravações reais.

## Ordem de remediação

1. Corrigir MFA/AAL2 e políticas RLS por domínio.
2. Implementar decisão de consentimento por RPC auditada.
3. Reforçar chaves compostas e restrições de escopo/validade.
4. Atualizar preflight, rollback e testes negativos.
5. Executar validação local; somente então abrir o portão remoto da `0028`.
