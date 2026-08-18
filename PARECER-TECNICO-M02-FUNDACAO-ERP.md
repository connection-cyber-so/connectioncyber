# ConnectionCyber — Parecer técnico M02

## Fundação ERP multiempresa e multissegmento

**Ambiente:** `connectioncyber-staging`

**Data:** 18/08/2026

**Versão:** 1.0.0

**Situação:** pacote SQL apresentado para revisão; ainda não aplicado

**Produção alterada:** não

## 1. Parecer executivo

O desenho físico do M02 é **tecnicamente favorável para validação em laboratório e, depois, no Supabase staging**, desde que os portões descritos neste documento sejam respeitados.

A migration `0016_erp_foundation.sql` é aditiva e cria uma fundação independente do sistema legado. Ela não cria produtos, vendas, estoque, fiscal, Mercado Pago, certificado A1 nem importa dados de clientes. Seu objetivo é estabelecer as fronteiras que todos os módulos futuros deverão obedecer:

- usuário pode participar de uma ou mais empresas por membership;
- cada registro operacional pertence a uma empresa (`tenant_id`);
- loja, filial, oficina ou unidade é representada por estabelecimento;
- segmentos habilitam combinações de capacidades, sem criar versões diferentes do ERP;
- papéis e permissões não podem cruzar empresas por erro de referência;
- configurações comuns não podem receber chaves com nomes de segredo;
- numerações são alocadas de forma transacional;
- auditoria é append-only;
- navegador autenticado começa com leitura protegida por RLS e sem escrita direta.

**Conclusão deste portão:** o SQL pode ser revisado. Ainda não há autorização para `db push`, aplicação remota ou povoamento.

## 2. Como a fundação ficará

```mermaid
flowchart LR
  U[Usuário autenticado] --> M[Membership]
  M --> T[Empresa / tenant]
  M --> MR[Papéis da membership]
  MR --> R[Papel do tenant]
  R --> RP[Permissões]

  T --> E[Estabelecimentos]
  T --> TC[Capacidades habilitadas]
  SP[Perfil de segmento] -. recomenda .-> TC
  T --> CFG[Configurações sem segredos]
  E --> CFG
  T --> SEQ[Sequências transacionais]
  E --> SEQ
  T --> AUD[Auditoria append-only]

  RLS{RLS + FKs compostas} --- M
  RLS --- E
  RLS --- TC
  RLS --- CFG
  RLS --- AUD
```

Exemplos de composição, usando o mesmo núcleo:

| Empresa | Perfil primário | Capacidades adicionais possíveis |
|---|---|---|
| Papelaria/variedades | `apparel_stationery` | variações, etiquetas, estoque, PDV, fiscal |
| Varejo geral | `retail_general` | compras, orçamentos, caixa, financeiro |
| Oficina | `workshop` | veículos, ativos, ordens de serviço, peças |
| Restaurante/lanchonete | `food_service` | receitas, lotes, mesas, comandas, cozinha |
| Prestador de serviços | `professional_services` | agenda futura, OS, atendimento, financeiro |

Um perfil é somente um template de recomendação. A fonte efetiva do que a empresa utiliza será `erp_tenant_capabilities`.

## 3. Migration apresentada

**Arquivo:** `supabase/migrations/0016_erp_foundation.sql`

### 3.1 Objetos criados

| Grupo | Tabela | Função |
|---|---|---|
| Identidade | `erp_tenant_memberships` | vínculo usuário ↔ empresa, com vigência e status |
| Identidade | `erp_roles` | papéis próprios de cada empresa |
| Identidade | `erp_permissions` | catálogo global de ações autorizáveis |
| Identidade | `erp_role_permissions` | permissões concedidas ao papel |
| Identidade | `erp_membership_roles` | papéis concedidos à membership |
| Organização | `erp_establishments` | matriz, filial ou unidade operacional |
| Capacidades | `erp_capability_catalog` | catálogo técnico global do ERP |
| Capacidades | `erp_tenant_capabilities` | capacidades realmente habilitadas por empresa |
| Segmentos | `erp_segment_profiles` | cinco perfis iniciais reutilizáveis |
| Segmentos | `erp_segment_profile_capabilities` | recomendações de capacidade por perfil |
| Segmentos | `erp_tenant_segment_profiles` | perfis associados à empresa |
| Configuração | `erp_tenant_settings` | parâmetros JSON sem credenciais |
| Operação | `erp_number_sequences` | numeração concorrente por empresa/unidade |
| Auditoria | `erp_audit_events` | eventos imutáveis de negócio e segurança |

Total: **14 tabelas**, todas com RLS habilitada.

### 3.2 Catálogos globais incluídos

A migration cadastra somente referências técnicas, sem clientes:

- 8 permissões iniciais;
- 23 capacidades do ERP;
- 5 perfis de segmento;
- associações recomendadas entre perfil e capacidade.

Esses dados são infraestrutura do produto. Não há CNPJ, razão social, e-mail, estoque, preço, venda ou informação fiscal real.

### 3.3 Decisões de segurança

- `erp_security` não está nos schemas expostos pelo Data API.
- Helpers `security definer` usam `search_path` vazio e nomes totalmente qualificados.
- `anon` não recebe privilégio nas tabelas ERP.
- `authenticated` recebe somente `SELECT`; não recebe `INSERT`, `UPDATE` ou `DELETE`.
- Escritas permanecem server-only até a implementação dos fluxos de autorização do M04.
- FKs compostas `(tenant_id, id)` impedem associar membership, papel ou estabelecimento de outra empresa.
- A auditoria rejeita `UPDATE` e `DELETE`; correções devem ser novos eventos.
- A membership referenciada por auditoria não poderá ser apagada; deve ser revogada, preservando histórico.
- Chaves de configuração contendo `secret`, `password`, `token`, `credential`, `certificate` ou `pfx` são recusadas.
- A alocação de números usa bloqueio de linha (`FOR UPDATE`) e não é executável pelo usuário autenticado.

### 3.4 Compatibilidade com o projeto atual

O desenho não substitui imediatamente `users.tenant_id` nem modifica as funções de login existentes. As memberships entram de modo aditivo. A troca da resolução de empresa ativa será feita no M03/M04, com teste de compatibilidade.

`erp_capability_catalog` também não reutiliza `module_catalog`: o primeiro descreve funções técnicas do ERP; o segundo continua descrevendo serviços comerciais da ConnectionCyber.

## 4. Pacote de testes apresentado

### 4.1 Pré-validação remota, somente leitura

**Arquivo:** `supabase/preflight/0016_erp_foundation_preflight.sql`

Ele interrompe o processo se:

- PostgreSQL for anterior à versão 15;
- `tenants`, `users`, `set_updated_at` ou `is_platform_staff` estiverem ausentes;
- qualquer uma das 14 tabelas já existir;
- o schema privado `erp_security` já existir;
- a versão `0016` já constar no histórico remoto.

O preflight não cria nem altera objetos.

### 4.2 Testes automatizados pgTAP

**Arquivo:** `supabase/tests/0016_erp_foundation.test.sql`

Foram especificadas **38 asserções**:

| Bloco | Cobertura |
|---|---|
| Estrutura | schema privado e 14 tabelas presentes |
| RLS | RLS habilitada nas 14 tabelas |
| Seeds | 23 capacidades e 5 perfis |
| Grants | sem DML para `authenticated`; sem privilégios para `anon` |
| Funções | helpers mínimos liberados; numeração negada ao navegador |
| Isolamento | usuário A não enxerga memberships, unidades, capacidades, configurações, perfis e papéis de B |
| Auditoria | ator vê o próprio evento; update/delete são bloqueados |
| Integridade | referências cross-tenant de papel/estabelecimento, segredo em configuração e ator incompatível falham |
| Concorrência básica | sequência retorna `A-0001` e depois `A-0002` |

Os fixtures usam domínios `.invalid`, UUIDs sintéticos e transação com `ROLLBACK`; não são dados de cliente.

### 4.3 Rollback e forward-fix

**Arquivo:** `supabase/rollback/0016_erp_foundation.rollback.sql`

O rollback é deliberadamente bloqueado e serve apenas para laboratório local descartável. Ele exige duas confirmações explícitas e recusa execução se encontrar qualquer linha vinculada a tenant.

Depois que uma migration for aplicada em ambiente compartilhado ou receber dados, a estratégia oficial é **forward-fix**: criar uma migration `0017+` aditiva/corretiva, preservar o histórico e executar novos testes. Não se apaga uma fundação com dados para “voltar”.

## 5. Validações já realizadas nesta apresentação

| Verificação | Evidência | Resultado |
|---|---|---|
| Escopo do Git | somente `connectioncyber-staging` | aprovado |
| Produção | nenhum arquivo alterado nesta etapa | aprovado |
| Transação da migration | um `BEGIN` e um `COMMIT` | aprovado |
| Quantidade estrutura/RLS/policies | 14/14/14 | aprovado |
| Busca por segredos e dados reais conhecidos | nenhuma ocorrência | aprovado |
| Espaços/erros de patch (`diff --check`) | aprovado após normalização |
| Aplicação em banco local | não executada; Docker local está parado |
| Preflight remoto | não executado; depende do próximo aceite |
| Dry-run remoto | não executado; depende do próximo aceite |
| Aplicação no Supabase staging | não autorizada/não executada |

Portanto, o resultado correto deste momento é **SQL preparado e estaticamente revisado**, e não “migration validada no banco”.

## 6. Riscos e controles

| ID | Risco | Nível | Controle deste M02 | Condição residual |
|---|---|---:|---|---|
| M02-R1 | vazamento entre empresas | crítico | RLS, memberships e FKs compostas | executar 38 testes em banco descartável e staging |
| M02-R2 | escrita direta pelo navegador | crítico | grants somente leitura | comandos de escrita entram apenas com serviços do M04 |
| M02-R3 | segredo em configuração comum | crítico | bloqueio por chave e regra documental | A1 terá cofre/serviço específico no M13 |
| M02-R4 | números duplicados sob concorrência | alto | unicidade de escopo + lock de linha | teste concorrente ampliado no módulo transacional |
| M02-R5 | perda de auditoria | alto | append-only e delete restrito | política de retenção/backup ainda será definida |
| M02-R6 | acesso administrativo amplo | alto | somente papel de equipe existente e RLS | rotas administrativas auditadas serão exigidas no M03/M04 |
| M02-R7 | rollback após dados | crítico | script recusa se houver linhas de tenant | usar sempre forward-fix em ambiente compartilhado |
| M02-R8 | incompatibilidade com login atual | alto | memberships aditivas; `users.tenant_id` preservado | resolver empresa ativa somente no M03/M04 |

## 7. Processo determinístico de execução

```mermaid
flowchart LR
  A[Pacote M02 apresentado] --> B{Revisão aprovada?}
  B -- não --> C[Corrigir SQL e documentos]
  C --> A
  B -- sim --> D[Preflight somente leitura em staging]
  D --> E{Preflight aprovado?}
  E -- não --> C
  E -- sim --> F[Dry-run: somente 0016]
  F --> G{Plano exato?}
  G -- não --> C
  G -- sim --> H[Teste em banco local descartável]
  H --> I{38/38?}
  I -- não --> C
  I -- sim --> J[Novo aceite para aplicar em staging]
  J --> K[Aplicar 0016 em staging]
  K --> L[Reexecutar 38 testes e inspeções]
  L --> M{Tudo aprovado?}
  M -- não --> N[Forward-fix 0017+]
  M -- sim --> O[Checkpoint M02 e atualização MD/HTML]
```

Cada caixa é um portão. Nenhuma falha autoriza pular para a seguinte.

## 8. Próximo aceite solicitado

O próximo passo ainda não aplica a migration. Ele autoriza somente:

1. executar o preflight somente leitura no Supabase staging;
2. executar o dry-run da migration;
3. preparar/ativar o banco local descartável;
4. aplicar `0016` apenas nesse banco local;
5. executar as 38 asserções pgTAP;
6. apresentar as evidências e pedir uma nova autorização antes do `db push` em staging.

Frase de aceite sugerida:

> **M02 SQL e testes aprovados; executar preflight, dry-run e laboratório local.**
