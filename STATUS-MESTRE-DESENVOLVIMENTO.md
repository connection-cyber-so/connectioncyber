# ConnectionCyber — Status Mestre de Desenvolvimento

**Documento vivo e obrigatório**

**Ambiente de trabalho:** staging

**Atualizado em:** 18/08/2026

**Versão do documento:** 1.8.0

**Produção alterada nesta fase:** não

## 1. Finalidade

Este documento é a fonte operacional do desenvolvimento controlado da ConnectionCyber. Ele registra, antes de qualquer implementação:

- o estado comprovado do projeto;
- o que já foi validado;
- o que ainda não foi executado;
- a ordem dos módulos;
- os riscos e dependências;
- os critérios objetivos de aceite;
- as decisões e mudanças de status.

Os arquivos `STATUS-MESTRE-DESENVOLVIMENTO.md` e `STATUS-MESTRE-DESENVOLVIMENTO.html` devem permanecer equivalentes. A atualização dos dois formatos faz parte da definição de pronto de cada módulo.

## 2. Regra determinística de desenvolvimento

Nenhum módulo avança automaticamente apenas porque o código foi escrito. A sequência obrigatória é:

1. registrar objetivo, escopo, riscos e critério de aceite neste documento;
2. verificar dependências, dados, ambiente e possibilidade de rollback;
3. implementar somente em `connectioncyber-staging`;
4. executar testes, análise estática, build e verificações de segurança proporcionais ao risco;
5. validar o comportamento no ambiente de staging/Preview quando aplicável;
6. atualizar os dois formatos deste documento com evidências e resultado;
7. criar um commit de checkpoint;
8. somente depois avaliar promoção para o próximo portão;
9. produção exige autorização e checklist próprios.

Se uma etapa falhar, o desenvolvimento permanece no mesmo portão. Nenhum erro será contornado com exclusão automática de dados, redução de segurança ou alteração silenciosa de produção.

## 3. Estados oficiais dos módulos

| Estado | Significado |
|---|---|
| Não iniciado | Existe apenas na fila; nenhum schema ou código foi criado. |
| Em análise | Requisitos e dependências estão sendo levantados. |
| Planejado | Escopo e critérios foram definidos, aguardando implementação. |
| Em desenvolvimento | Alterações locais em staging estão em andamento. |
| Validado localmente | Testes e build locais foram aprovados. |
| Validado em staging | Banco de staging, CI e Preview foram aprovados. |
| Aprovado para promoção | Evidências revisadas e portão concluído. |
| Em produção | Promoção concluída e smoke test de produção aprovado. |
| Bloqueado | Dependência externa ou risco impede avanço seguro. |

## 4. Arquitetura aprovada

### 4.1 Repositório e aplicações

- Um monorepo GitHub: `connection-cyber-so/connectioncyber`.
- Branch `main`: produção.
- Branch `staging`: desenvolvimento e validação.
- `apps/site`: site institucional e páginas públicas.
- `apps/platform`: painel interno da equipe ConnectionCyber.
- `apps/portal`: portal/ERP de clientes proposto; ainda não criado.
- `packages/core`: regras compartilhadas; ainda sem núcleo ERP implementado.

Não serão criados novos repositórios, bancos ou forks de aplicação por cliente como padrão. Cada empresa será um tenant isolado na plataforma comum. A migração e o corte serão individuais por cliente.

### 4.2 Dados e ambientes

- Supabase produção: projeto `qfggetvashdxyuvlhihq`.
- Supabase staging: projeto `ozvylnaipubrmaadikvk`.
- Os relatórios fornecidos mostram 38 tabelas e o mesmo conteúdo lógico de schema/policies nos dois projetos até a migration `0013`.
- Migrations `0014` e `0015` foram aplicadas exclusivamente no Supabase staging em 18/08/2026.
- A migration `0016_erp_foundation.sql` foi aplicada exclusivamente no Supabase staging em 18/08/2026 e validada por 38 asserções remotas.
- A migration `0006`, que contém povoamento de clientes reais, foi registrada no histórico de staging sem executar seus `INSERTs`.
- Vercel Production deve apontar exclusivamente para o Supabase de produção.
- Vercel Preview/branch staging deve apontar exclusivamente para o Supabase de staging.

### 4.3 Multiempresa

- Um cliente é representado por uma linha em `tenants`.
- O isolamento é realizado por `tenant_id` e Row Level Security.
- O tenant nunca pode ser aceito de formulário, query string ou payload do navegador como autoridade de acesso.
- A equipe ConnectionCyber usa papéis administrativos controlados e auditados.
- Configurações, módulos, temas, contratos e migrações são vinculados ao tenant.
- Um usuário poderá participar de múltiplos tenants por `erp_tenant_memberships`; o atual `users.tenant_id` será mantido apenas durante a transição.
- Segmentos são perfis de configuração, não versões do sistema nem fronteiras de autorização.
- Capacidades ERP serão separadas do `module_catalog` atual, que representa serviços comerciais da ConnectionCyber.
- O modelo ERP usará tabelas `erp_*` para evitar colisão com o site, Mercado Pago e módulos MPI.

### 4.4 Certificado A1 e autenticação

O certificado digital A1 é uma credencial fiscal e não substitui a autenticação dos usuários. São domínios separados:

- usuários: Supabase Auth, sessão, MFA, papéis e permissões;
- certificado A1: assinatura/transmissão fiscal, armazenamento protegido e acesso restrito;
- banco legado: autenticação SQL Server/Windows, usada somente durante engenharia reversa e migração.

Arquivos `.pfx`, senhas de certificado, backups de clientes e credenciais não podem ser armazenados no Git, no navegador ou em tabelas comuns.

## 5. Estado atual comprovado

### 5.1 Concluído e validado localmente

- Site institucional existente em Next.js/TypeScript.
- Painel interno com autenticação de equipe e bloqueio de clientes/alunos.
- Arquitetura multi-tenant com `tenants`, `tenant_modules` e RLS.
- Lista de tenants no painel, atualmente somente leitura.
- Quatro módulos de negócio existentes: Diagnóstico Digital, Produtos/Ofertas, Roteiros de Vídeo e Landing Pages.
- Mercado Pago protegido por kill switch de produção.
- Autoridade de preço e total do checkout movida para o servidor.
- Webhook Mercado Pago com validação, reconciliação e idempotência.
- Rate limit do formulário público preparado em migration local.
- Headers de segurança, atualização de dependências e CI preparados.
- Next.js 15.5.21 nas duas aplicações.
- Testes críticos do site: 5/5 aprovados.
- TypeScript, lint e build aprovados para site e painel.
- Auditoria de dependências de runtime: zero vulnerabilidades reportadas.

### 5.2 Evidências remotas do M00

- Commit: `0caf472 feat: harden staging security and quality gates`.
- Commit documental: `8e8db94 docs: add living development status`.
- Os dois commits foram enviados para `origin/staging`.
- Supabase CLI vinculado ao projeto de staging `ozvylnaipubrmaadikvk`.
- Preflight de `payments`: zero grupos duplicados por `gateway` e `transaction_id`.
- Dry-run selecionou exclusivamente `0014_payment_webhook_hardening.sql` e `0015_api_rate_limits.sql`.
- Histórico local/remoto alinhado de `0001` a `0015`.
- Coluna de auditoria, índice único, tabela com RLS e permissões da função de rate limit foram comprovados remotamente.
- GitHub Actions `Quality gates`, execução `32184886056`: trabalhos `site` e `platform` concluídos com sucesso.
- Vercel deployment `dpl_FWKKPeaCBwjqbjcnuRzxV4eYHXEF`: concluído com sucesso.
- Preview `connectioncyber-git-staging-connectioncyberso.vercel.app`: HTTP 200, Supabase staging presente e referência de produção ausente nos artefatos públicos.
- Cabeçalhos CSP, `DENY`, `nosniff` e Permissions Policy presentes; `X-Powered-By` ausente.
- Endpoint de pagamentos no Preview respondeu HTTP 503, mantendo o Mercado Pago desabilitado.
- `RATE_LIMIT_SALT` criada como variável sensível e limitada a `Preview (staging)`, sem revelar ou persistir seu valor no repositório.
- Redeploy `dpl_34HEEiQXwbaAJR6w79DdRZKaLU2S`: target `preview`, estado `Ready` e alias da branch staging confirmado.
- Smoke test final do formulário: HTTP 200 e `ok=true`; exatamente uma chave recente de rate limit comprovou a execução da proteção.
- Exatamente uma mensagem sintética foi criada e removida; a verificação final confirmou zero mensagens sintéticas remanescentes.
- Pastas de referência preexistentes `icones/` e `modelo exemplo/` permanecem preservadas e fora do commit técnico.

### 5.3 Resultado do M00

- Estado: `Validado em staging`.
- O bloqueio da variável privada foi corrigido sem reduzir as proteções do código.
- Banco, CI, Vercel Preview, vínculo de ambiente, cabeçalhos, kill switch, formulário e rate limit foram aprovados.
- Produção, domínio público e Mercado Pago real não foram alterados.
- A proteção das tabelas auxiliares e a estratégia de backup/restauração continuam como riscos abertos dos próximos portões, antes de receber dados ERP sensíveis.

### 5.4 M01 — arquitetura canônica multissegmento

- O responsável aprovou que o ERP seja projetado novo e independente do schema legado.
- Papelaria, vestuário, artesanato, varejo geral, oficinas, restaurantes, lanchonetes e prestadores utilizarão o mesmo núcleo.
- Segment profiles somente sugerem capacidades; `erp_tenant_capabilities` registra o que cada tenant efetivamente utiliza.
- O catálogo universal representa produtos, serviços, peças, ingredientes, preparados, kits, insumos, taxas e vales.
- Memberships permitirão que o mesmo usuário participe de mais de uma empresa com papéis diferentes.
- Estabelecimentos serão a fronteira operacional para estoque, caixa, emissão, numeração e calendário.
- Estoque, caixa, financeiro e fiscal usarão livros razão e correções por estorno/contrapartida.
- O modelo lógico foi separado das tabelas atuais do site, Mercado Pago, MPI e catálogo comercial de serviços.
- O contrato do M02 foi fechado para memberships, estabelecimentos, capacidades, perfis, configurações, sequências, auditoria, RLS e testes cross-tenant.
- Especificação publicada em `ARQUITETURA-CANONICA-MULTISSEGMENTO.md` e `.html`.
- Checkpoint arquitetural `1feb493` enviado exclusivamente para `origin/staging`.
- GitHub Actions `Quality gates` `32192279665`: concluído com sucesso.
- Vercel Preview `dpl_DNFfHanCrdhhGUAvQ7LVxJ3HLj5m`: estado `Ready` e alias staging confirmado.
- Estado do M01: `Aprovado`; aceite formal recebido em 18/08/2026 para apresentar o M02.
- Nenhuma migration, tabela, dado real, credencial, A1 ou integração de pagamento foi criada ou alterada no M01.

### 5.5 Estudo D01 — engenharia reversa preservado

- O inventário anterior de 68 arquivos e seu manifesto permanecem válidos como evidência.
- `PARECER-TECNICO-M01-ENGENHARIA-REVERSA.*` foi reclassificado como estudo D01 vinculado ao M14.
- A ausência de backup não bloqueia o desenvolvimento do ERP.
- No M14, uma cópia representativa será restaurada isoladamente e convertida por adaptador para o modelo canônico; o legado não determinará nossa estrutura.

### 5.6 M02 — fundação validada em staging

- Migration aditiva `0016_erp_foundation.sql` aplicada exclusivamente no projeto staging `ozvylnaipubrmaadikvk`.
- 14 tabelas `erp_*`, 14 policies e RLS nas 14 tabelas.
- Memberships multiempresa, RBAC por tenant, estabelecimentos, capacidades, perfis, configurações sem segredos, sequências e auditoria append-only.
- Catálogos globais com 8 permissões, 23 capacidades e 5 perfis, sem dados de cliente.
- `anon` sem privilégio; `authenticated` apenas com leitura protegida por RLS; escrita reservada ao servidor.
- Preflight somente leitura preparado e aprovado para versão, dependências, colisões e histórico.
- Suíte pgTAP com 38 asserções aprovada em duas passagens para estrutura, grants, RLS, isolamento cross-tenant, integridade, numeração e auditoria.
- Rollback restrito a laboratório local vazio aprovado; em ambiente compartilhado será usado forward-fix.
- Revisão estática confirmou 14 tabelas/14 RLS/14 policies e nenhuma ocorrência conhecida de segredo ou dado real.
- Parecer detalhado publicado em `PARECER-TECNICO-M02-FUNDACAO-ERP.md` e `.html`.
- Checkpoint técnico `d5f5ce1` enviado exclusivamente para `origin/staging`.
- GitHub Actions `Quality gates` `32194798896`: concluído com sucesso.
- Vercel reportou `success` para o mesmo commit e o alias Preview respondeu HTTP 200.
- Preflight remoto somente leitura: `M02_PREFLIGHT_OK` no Supabase staging, PostgreSQL 17.6.
- Dry-run remoto: exclusivamente `0016_erp_foundation.sql`, sem seeds ou roles.
- Aplicação local completa das migrations `0001`–`0016`: aprovada.
- Suíte pgTAP executada antes e depois do rollback/rebuild: 38/38 nas duas passagens.
- Rollback de laboratório: aprovado, com zero tabelas ERP e zero schema `erp_security` remanescentes.
- Laboratório encerrado com `--no-backup`; contêineres e volume de dados locais foram descartados.
- Verificação remota final: migration 0016 presente; 14 tabelas ERP, 14 RLS e 14 policies.
- Catálogos remotos: 8 permissões, 23 capacidades, 5 perfis e 60 associações perfil-capacidade.
- Grants remotos: `anon` sem privilégios; `authenticated` sem DML, com SELECT nas 14 tabelas protegido por RLS; helpers de numeração não executáveis pelo navegador.
- A primeira tentativa remota da suíte parou antes das asserções porque o papel da CLI não possuía `USAGE` em `extensions`; nenhum fixture havia sido criado.
- O harness pgTAP foi tornado portável com elevação local e transitória para `postgres`, preservando a alternância para `authenticated` nas provas de RLS e o rollback integral.
- Suíte pgTAP remota: `Files=1, Tests=38, Result: PASS`.
- Conferência pós-rollback: zero tenants, usuários, profiles e eventos sintéticos; zero linhas nas tabelas tenant-owned e zero extensão pgTAP persistida.
- Lint remoto dos schemas `public` e `erp_security`: nenhum erro de schema no nível warning.
- Checkpoint técnico `1a0c47f` enviado exclusivamente para `origin/staging`; Quality Gates `32197876637` concluído com sucesso, Vercel `success` e Preview HTTP 200.
- A pilha local completa teve timeout do serviço auxiliar `postgres-meta`; o laboratório mínimo somente PostgreSQL funcionou e é suficiente para este portão.
- A migration histórica `0006` repovoa cadastros em resets locais; ficou isolada, não foi selecionada pelo dry-run remoto e seu volume local foi removido ao final.
- Produção não foi alterada. O staging contém apenas a fundação e seus catálogos técnicos; não recebeu empresas, dados fiscais, A1, Mercado Pago ou backup legado pelo M02.
- Aceite formal do M02 recebido em 18/08/2026; módulo promovido para `Aprovado` e análise M03 autorizada.

### 5.7 M03 — portal e subdomínios em análise

- O repositório ainda não possui `apps/portal`; nenhum código funcional M03 foi criado.
- `apps/site` permanecerá institucional/alunos/pagamentos e `apps/platform` continuará exclusivo da equipe.
- Arquitetura recomenda uma terceira aplicação Next.js App Router no mesmo monorepo e um projeto Vercel próprio com Root Directory `apps/portal`.
- O contexto autorizado será a interseção de hostname ativo, tenant ativo, sessão validada e membership ativa.
- `tenant_id` vindo do navegador, URL, formulário, query string ou armazenamento local não será autoridade.
- O portal não usará `users.tenant_id`; a fonte será `erp_tenant_memberships`.
- O modelo proposto adiciona `erp_tenant_domains` e um resolver público mínimo, sem SELECT anônimo direto na tabela.
- Entrada central proposta: `portal.connectioncyber.com.br`; subdomínios piloto serão explícitos e cadastrados individualmente.
- DNS atual usa `ns1.dns-parking.com`/`ns2.dns-parking.com`; wildcard Vercel exige nameservers, portanto nenhuma migração DNS ou wildcard está autorizada no M03 inicial.
- Cookies serão host-only; não haverá compartilhamento amplo com `www` ou todos os subdomínios.
- Staff não receberá bypass automático no portal: o guard exigirá membership ativa do próprio `auth.uid()`.
- M03 entregará shell, hostname, sessão e isolamento; convites, usuários, RBAC e MFA permanecem no M04.
- Parecer e desenho publicados em `PARECER-TECNICO-M03-PORTAL-SUBDOMINIOS.md` e `.html`.
- Produção, Supabase remoto, Vercel, DNS, dados reais, fiscal, A1, Mercado Pago e backups não foram alterados nesta análise.

## 6. Achados críticos ainda abertos

| ID | Achado | Severidade | Tratamento obrigatório |
|---|---|---:|---|
| R-001 | `client_services`, `remote_configs` e `remote_automations` não possuem isolamento adequado para receber dados sensíveis. | Crítica | RLS/revogação de acesso e remodelagem por `tenant_id` antes de uso. |
| R-002 | As telas fornecidas não revelam nomes físicos, chaves, triggers, procedures e versões do banco SQL Server legado. | Alta | Restaurar um backup representativo em ambiente isolado e gerar dicionário técnico. |
| R-003 | As imagens do Supabase não demonstram backup gerenciado ou restauração testada. | Crítica | Definir RPO/RTO e provar restauração antes do piloto. |
| R-004 | Impressoras, balanças, TEF, gavetas e A1 podem exigir integração local. | Crítica | Prova técnica de agente local e inventário de equipamentos por cliente. |
| R-005 | Continuidade do PDV sem internet ainda não foi definida. | Crítica | Decidir contingência/offline antes do módulo de vendas. |
| R-006 | A lista documental de clientes possui divergências de quantidade, e-mail e subdomínio. | Alta | Criar cadastro mestre validado antes de provisionamento em massa. |
| R-007 | Existe repositório histórico específico de cliente, divergente do padrão multi-tenant aprovado. | Média | Auditar e incorporar somente ativos necessários; não criar novos forks. |
| R-008 | Não há arquivo de backup no acervo analisado. | Planejado | Não bloqueia o ERP; antes do M14, receber cópia protegida fora do Git, registrar metadados e SHA-256. |
| R-009 | O schema atual possui colisão semântica com nomes do futuro ERP e 16 tabelas públicas observadas sem RLS. | Crítica | Criar modelo `erp_*` isolado no M02; não carregar legado em tabelas do site, Mercado Pago ou suporte remoto. |
| R-010 | O modelo atual assume predominantemente um tenant por usuário em `users.tenant_id`. | Alta | Introduzir memberships aditivas no M02/M04 e resolver tenant ativo no servidor. |
| R-011 | `module_catalog` mistura o conceito de serviço contratado com o de capacidade técnica do ERP. | Alta | Criar catálogo ERP próprio; manter o catálogo comercial existente sem reutilização semântica. |
| R-012 | Acesso administrativo cross-tenant ainda depende do papel de equipe existente e não possui fluxo ERP auditado próprio. | Alta | Manter escrita server-only no M02 e implementar rotas administrativas auditadas no M03/M04. |
| R-013 | A migration histórica `0006` contém povoamento e é reaplicada em resets locais. | Alta | Manter laboratório isolado; revisar política de fixtures históricas antes do M14/piloto; dry-run remoto deve continuar selecionando apenas migrations novas. |

## 7. Programa de módulos e portões

| Ordem | Módulo/portão | Estado atual | Entrega principal | Critério para avançar |
|---:|---|---|---|---|
| M00 | Segurança e qualidade de staging | Aprovado | Migrations, variáveis, CI, Preview e smoke tests aprovados | Concluído e aceito em 18/08/2026. |
| M01 | Arquitetura canônica multissegmento | Aprovado | Núcleo universal, capacidades, catálogo lógico, invariantes e contrato do M02 | Concluído e aceito em 18/08/2026; nenhum schema aplicado. |
| M02 | Fundação ERP multiempresa | Aprovado | Memberships, estabelecimentos, capacidades, configurações, sequências, auditoria e isolamento | Concluído e aceito em 18/08/2026; 0016 permanece somente em staging. |
| M03 | Portal do cliente e subdomínios | Em análise | `apps/portal`, autenticação e resolução segura de hostname | Parecer/visual apresentados; aguarda aceite para preparar código, migration 0017 e testes sem aplicação remota. |
| M04 | Usuários, RBAC e MFA | Não iniciado | Papéis, permissões por ação e convites | Matriz de acesso validada; nenhuma senha legada migrada. |
| M05 | Cadastros e catálogo universal | Não iniciado | Pessoas, produtos, serviços, peças, ingredientes, variações, unidades e composições | Cinco segmentos representados sem fork ou dado real. |
| M06 | Preços, estoque e compras | Não iniciado | Listas, depósitos, movimentos, inventário, lotes, séries e pedidos | Saldo sempre derivado do livro de movimentos; testes de concorrência aprovados. |
| M07 | Vendas, orçamento e PDV | Não iniciado | Orçamentos, vendas, pagamentos, caixa e comprovantes | Totais por dia/item/pagamento e estoque/caixa reconciliados. |
| M08 | Financeiro e bancário | Não iniciado | Receber, pagar, fluxo de caixa, cartões, cheques e boletos | Saldos em aberto e liquidações coincidem com o legado. |
| M09 | Serviços e oficinas | Não iniciado | Ativos, veículos, agenda, OS, peças, mão de obra e histórico | OS fecha materiais, serviços, estoque e financeiro transacionalmente. |
| M10 | Restaurantes e lanchonetes | Não iniciado | Receitas, adicionais, mesas, comandas e cozinha | Comanda fecha venda, insumos, caixa e fiscal sem duplicidade. |
| M11 | Atendimento e acesso remoto | Não iniciado | Tickets, SLA, dispositivos, consentimentos, sessões e auditoria | MFA, consentimento, expiração e revogação comprovados. |
| M12 | Agente local e periféricos | Não iniciado | Impressão, etiqueta, balança, TEF e contingência/offline | Testes físicos no piloto sem segredo exposto. |
| M13 | Fiscal e certificado A1 | Não iniciado | Perfis tributários, XML, NF-e/NFC-e e eventos | Homologação, contingência e ciclo do certificado aprovados. |
| M14 | Engenharia reversa e importador | Não iniciado | Laboratório, adaptadores, lotes, mapa de IDs e reconciliação | Reexecução não duplica; relatórios fecham contagens e totais. |
| M15 | Piloto e implantação por cliente | Não iniciado | Migração simulada, corte e ondas individuais | Aceite, reconciliação e rollback executados por tenant. |

## 8. Critérios globais de validação

Cada módulo deve demonstrar, quando aplicável:

- isolamento cross-tenant por testes positivos e negativos;
- migrations aditivas, revisáveis e com rollback/forward-fix definido;
- validação de entrada no servidor;
- nenhuma credencial ou dado de cliente no Git/log/browser;
- testes automatizados das regras críticas;
- type-check, lint e build aprovados;
- auditoria de dependências sem vulnerabilidade crítica/alta não tratada;
- logs com tenant, ator, ação, objeto, horário e resultado;
- idempotência em importações, webhooks e integrações;
- reconciliação quantitativa e financeira;
- evidência de backup/restauração antes de corte;
- atualização simultânea deste documento em Markdown e HTML.

## 9. Processo de migração por cliente

1. receber o backup e preservar o original como evidência imutável;
2. calcular hash e registrar origem/data;
3. restaurar uma cópia em ambiente SQL Server isolado;
4. inventariar schema, versões, volumes e integridade;
5. executar extração para área temporária protegida;
6. transformar para o modelo canônico, sempre atribuindo o tenant no servidor;
7. carregar em staging por job idempotente;
8. reconciliar clientes, produtos, estoque, vendas, caixa, contas e documentos fiscais;
9. obter aceite do cliente piloto;
10. executar corte final com janela, delta, smoke test e rollback disponível;
11. repetir o processo individualmente para o próximo cliente.

## 10. Próxima ação autorizável

### Apresentação do pacote implementável M03

Próxima sequência permitida:

1. criar o esqueleto revisável de `apps/portal` somente na branch staging;
2. apresentar middleware/guards, telas de login, seleção, 403, 404 e shell inicial;
3. apresentar migration `0017_portal_tenant_resolution.sql`, preflight e rollback/forward-fix;
4. apresentar testes unitários, pgTAP e matriz E2E, sem aplicação remota;
5. adicionar o job `portal` ao CI e executar validações locais;
6. não criar projeto/domínio Vercel nem alterar DNS neste portão;
7. manter produção, dados reais, backup legado, fiscal, A1 e Mercado Pago fora.

Comando de aceite sugerido: `Parecer M03 aprovado; apresentar código, migration 0017 e testes do portal, sem aplicar remotamente.`

## 11. Histórico do documento

| Versão | Data | Módulo | Alteração | Resultado |
|---|---|---|---|---|
| 1.0.0 | 18/08/2026 | Governança | Criação do documento mestre com baseline, riscos, fila e critérios. | Aguardando validação do documento antes do início do M00 remoto. |
| 1.1.0 | 18/08/2026 | M00 | Banco staging, push, CI, Preview e smoke tests executados; evidências registradas. | Bloqueado na configuração privada do formulário no Vercel Preview; produção não alterada. |
| 1.2.0 | 18/08/2026 | M00 | Variável sensível corrigida, redeploy de Preview e smoke test completo com limpeza do dado sintético. | Validado em staging; aguarda aceite explícito para iniciar a análise do M01. |
| 1.3.0 | 18/08/2026 | M01 | Inventário, análise do legado/stack, matriz preliminar, laboratório seguro, rollback e portões G0–G6 documentados. | M00 aprovado; M01-G0 aprovado e M01 bloqueado em G1 por ausência da cópia do backup; produção não alterada. |
| 1.3.1 | 18/08/2026 | M01 | Checkpoint documental remoto, Quality Gates e Vercel Preview registrados. | Documentação validada em staging; bloqueio seguro de M01-G1 mantido; produção não alterada. |
| 1.4.0 | 18/08/2026 | M01 | Escopo corrigido para arquitetura canônica multissegmento; núcleo, capacidades, catálogo, invariantes e contrato M02 documentados. | Engenharia reversa movida para M14; ausência de backup deixa de bloquear; aguarda validação remota do M01. |
| 1.4.1 | 18/08/2026 | M01 | Checkpoint, Quality Gates e Vercel Preview da arquitetura registrados. | M01 validado em staging; nenhuma migration/schema/dado real alterado; aguarda aceite para preparar M02. |
| 1.5.0 | 18/08/2026 | M02 | Migration 0016, preflight, 38 testes pgTAP, rollback de laboratório e parecer técnico apresentados. | Revisão estática concluída; nada aplicado; aguarda aceite para preflight, dry-run e laboratório local. |
| 1.5.1 | 18/08/2026 | M02 | Checkpoint técnico, Quality Gates e Vercel Preview do pacote M02 registrados. | Código/documentos validados no pipeline; migration continua não aplicada e aguarda o próximo aceite. |
| 1.6.0 | 18/08/2026 | M02 | Preflight, dry-run, aplicação local, 38 testes, rollback, reconstrução e nova passagem 38/38 executados. | Validado localmente; staging comprovadamente inalterado; aguarda autorização específica para aplicação remota. |
| 1.7.0 | 18/08/2026 | M02 | Migration 0016 aplicada somente em staging; estrutura, catálogos, grants, lint, resíduos e suíte pgTAP remota verificados. | Validado em staging com 38/38; produção intocada; aguarda aceite formal para iniciar a análise M03. |
| 1.8.0 | 18/08/2026 | M03 | M02 formalmente aprovado; inventário do portal, autenticação, Vercel e DNS; arquitetura, telas, modelo de domínio, riscos e portões M03 apresentados. | M03 em análise; nenhum código funcional, migration, Vercel, DNS, Supabase remoto ou produção alterado; aguarda aceite do parecer. |

## 12. Protocolo de atualização futura

Ao concluir qualquer portão, adicionar uma entrada ao histórico contendo:

- versão e data;
- módulo;
- commit;
- migrations envolvidas;
- testes executados;
- ambiente validado;
- evidências principais;
- riscos residuais;
- decisão: aprovado, reprovado ou bloqueado;
- próxima ação permitida.
