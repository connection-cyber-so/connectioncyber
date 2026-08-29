# M14-G3 — auditoria técnica final da migration 0031

Data: 29/08/2026
Ambiente: staging local
Migration auditada: `0031_m14_import_ledger.sql`
SHA-256: `ab297ff5046350d9fdc7f14dee2200137dc9080ff91245b2074439551148d74f`
Decisão: **REPROVADA PARA VALIDAÇÃO REMOTA; REMEDIAÇÃO LOCAL OBRIGATÓRIA**

## Evidências preservadas

- migration, preflight e rollback válidos no laboratório local;
- testes estáticos: `37/37`;
- pgTAP após correção nominal: `80/80` em duas passagens;
- sete tabelas com RLS e cinco RPCs `security definer` restritas ao `service_role`;
- zero registros, backups, payloads brutos ou dados reais;
- Supabase remoto e produção não acessados.

## Bloqueios

### B1 — corrida nas chaves idempotentes — crítica

As RPCs consultam e depois inserem. Duas transações simultâneas podem não encontrar o registro e competir no `INSERT`; uma delas recebe violação de unicidade em vez de replay determinístico. Manifesto, job, lote e item precisam de serialização por chave ou `INSERT ... ON CONFLICT` seguido de comparação integral.

### B2 — item pode mudar lote já reconciliado — crítica

`erp_record_import_item` não bloqueia nem valida o estado do lote. Um item pode ser incluído depois da reconciliação. A RPC de item deve bloquear a linha do lote e aceitar escrita somente em estados abertos; a finalização deve usar o mesmo bloqueio.

### B3 — vínculos compostos incompletos — alta

Uma rejeição pode referenciar um item de outro lote do mesmo tenant. Uma reconciliação pode combinar job e lote que não pertencem um ao outro. São necessárias FKs compostas contendo tenant, pai e filho.

### B4 — máquina de estados não aplicada — alta

As tabelas declaram estados, mas as RPCs não exigem manifesto validado, job em estado compatível ou lote aberto. O fluxo pode pular validação e criar estruturas fora de ordem.

### B5 — proteção contra caminhos e segredos é apenas nominal — alta

O bloqueio JSON examina nomes de chaves. Um caminho, DSN ou segredo pode ser armazenado sob uma chave com nome inocente. Metadados precisam de allowlist e bloqueio de padrões também nos valores.

### B6 — estado `blocked` é revertido junto com a exceção — média

Na divergência de reconciliação, a função atualiza o lote para `blocked` e em seguida lança exceção. A transação desfaz a atualização, portanto a evidência do bloqueio não permanece.

### B7 — permissão `import.execute` ainda não possui fluxo — média

A permissão é cadastrada, mas nenhuma RPC autenticada a utiliza. Deve permanecer sem concessão até existir um fluxo de solicitação com AAL2 e aprovação server-side, ou ser removida desta migration.

## Parecer

Os testes atuais comprovam existência, grants, RLS e constraints conhecidas, mas não cobrem concorrência e coerência de ciclo de vida. A aplicação remota da `0031` permanece proibida.

## Próxima etapa

M14-G4: remediação local dos sete bloqueios, testes concorrentes, ampliação do pgTAP e repetição completa de migration, rollback, zero resíduos e reconstrução.
