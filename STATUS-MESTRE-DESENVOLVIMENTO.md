# ConnectionCyber — Status Mestre de Desenvolvimento

**Documento vivo e obrigatório**

**Ambiente de trabalho:** staging

**Atualizado em:** 02/09/2026

**Versão do documento:** 2.3.1

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

A comunicação e a continuidade automática seguem `GOVERNANCA-EXECUCAO-AUTOMATICA.md`: atualizações intermediárias mínimas, documentação técnica integral e intervenção somente em portões que exigem autoridade, credenciais ou decisão do responsável.

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
- `apps/portal`: portal/ERP de clientes criado no M03, ainda sem projeto/domínio Vercel próprio.
- `packages/core`: regras compartilhadas; ainda sem núcleo ERP implementado.

Não serão criados novos repositórios, bancos ou forks de aplicação por cliente como padrão. Cada empresa será um tenant isolado na plataforma comum. A migração e o corte serão individuais por cliente.

### 4.2 Dados e ambientes

- Supabase produção: projeto `qfggetvashdxyuvlhihq`.
- Supabase staging: projeto `ozvylnaipubrmaadikvk`.
- Os relatórios fornecidos mostram 38 tabelas e o mesmo conteúdo lógico de schema/policies nos dois projetos até a migration `0013`.
- Migrations `0014` e `0015` foram aplicadas exclusivamente no Supabase staging em 18/08/2026.
- A migration `0016_erp_foundation.sql` foi aplicada exclusivamente no Supabase staging em 18/08/2026 e validada por 38 asserções remotas.
- A migration `0017_portal_tenant_resolution.sql` foi aplicada exclusivamente no Supabase staging em 18/08/2026 e validada por 35 asserções remotas transacionais.
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

### 5.7 M03 — portal e subdomínios validados em staging

- Parecer M03 aprovado formalmente em 18/08/2026; autorização limitada a apresentar código, SQL e testes sem aplicação remota.
- Criado `apps/portal` em Next.js 15 App Router, separado de `apps/site` e `apps/platform`, com 36 arquivos de código/configuração e lock reproduzível.
- Implementados login, logout, seleção multiempresa, troca de empresa, 403, 404, estado sem membership e shell ERP somente leitura.
- Middleware renova a sessão com `getUser()`, sobrescreve o hostname interno da requisição e aplica `private, no-store`.
- Guards puros exigem hostname resolvido, tenant ativo, usuário autenticado e membership ativa/vigente do próprio usuário.
- Todos os formulários POST aplicam validação same-origin antes de processar autenticação ou sessão.
- O portal ignora `tenant_id` enviado pelo navegador e não usa `users.tenant_id` como autoridade; staff sem membership não recebe bypass.
- Cookie `cc_portal_membership` é opaco, host-only, `HttpOnly`, `SameSite=Lax`, `Secure` em produção e revalidado contra usuário/tenant.
- Migration `0017_portal_tenant_resolution.sql` apresentada com `erp_tenant_domains`, normalização estrita, resolver público mínimo e policy multiempresa em `tenants`.
- Preflight `M03_PREFLIGHT_OK` aprovado em duas construções locais PostgreSQL 17.6.
- Dry-run aplicou somente `0017_portal_tenant_resolution.sql` em snapshot lógico descartável; SHA-256 `ac08fb…90c79`.
- Migration 0017 aplicada somente no laboratório Docker, com tabela, RLS, duas policies e funções comprovadas.
- Testes unitários locais: 19/19; TypeScript, lint e build Next.js aprovados.
- Inspeção visual local em 1440 px e 360 px: HTTP 200, sem overflow horizontal ou erro de navegador; formulário corretamente bloqueado sem variáveis staging.
- Job `portal` adicionado ao Quality Gates com `npm ci`, testes, type-check, lint e build.
- Checkpoint de código `285d103` e checkpoint de laboratório `563a669` publicados em `origin/staging`; Quality Gates `32204837889` concluído com `site`, `platform` e `portal` aprovados.
- A integração Vercel existente concluiu o Preview de staging com sucesso e HTTP 200; o aplicativo `apps/portal` não foi provisionado nem recebeu domínio ou variáveis.
- Relatório do pacote em `PACOTE-TECNICO-M03-PORTAL.md` e `.html`.
- Suíte pgTAP aprovada 35/35 antes e depois da destruição e reconstrução completa do laboratório.
- Fixture pgTAP tornou-se portátil: removeu dependência de `email_confirmed_at` e configura claims no GUC local e no JSON Supabase.
- Rollback recusou execução sem confirmações e com um domínio existente; após limpeza consciente, removeu somente objetos M03 e preservou M02.
- Fixtures, banco dry-run, contêiner e rede M03 terminaram com zero resíduos; os demais contêineres locais permaneceram ativos.
- Autorização remota específica recebida em 18/08/2026 para aplicar somente a 0017 no projeto staging `ozvylnaipubrmaadikvk`.
- Vínculo e baseline confirmados: migrations 0001–0016 alinhadas e 0017 ausente antes da execução.
- Preflight remoto: `M03_PREFLIGHT_OK`, PostgreSQL 17.6, fundação M02 presente, zero domínios legados e nenhum objeto conflitante.
- Dry-run remoto selecionou exclusivamente `0017_portal_tenant_resolution.sql`, sem seeds ou roles; SHA-256 `ac08fb…90c79`.
- Migration 0017 aplicada exclusivamente no Supabase staging; histórico remoto 0001–0017 alinhado depois da execução.
- Estrutura remota comprovada: tabela `erp_tenant_domains`, RLS ativa, duas policies, 12 constraints, 6 índices, trigger e duas funções com `search_path` fixo.
- Grants remotos comprovados: `anon` executa somente o resolver público; `authenticated` lê sob RLS e não possui DML; normalizador privado limitado ao `service_role`.
- Suíte pgTAP remota: 35/35 dentro de transação com rollback; zero fixtures de tenants, usuários, memberships, papéis e domínios depois da execução.
- Lint remoto dos schemas `public` e `erp_security`: zero erros; `erp_tenant_domains` permanece com zero linhas.
- Checkpoint remoto `0111056` publicado somente em `origin/staging`; Quality Gates `32206753538` com `site`, `platform` e `portal` aprovados.
- Integração Vercel concluída com status `success`; alias de staging HTTP 200. A branch `main` permaneceu em `59a3924`.
- Nenhum projeto/domínio do portal, Vercel, DNS, dado real, produção, fiscal, A1, Mercado Pago ou backup foi alterado.
- Aceite formal do M03 recebido em 18/08/2026; módulo promovido para `Aprovado` e M04-G0 autorizado.

### 5.8 M04-G0 — identidade de teste e provisionamento seguro especificados

- Parecer de arquitetura publicado em `PARECER-TECNICO-M04-G0-IDENTIDADE-PROVISIONAMENTO.md` e `.html`.
- Auditoria remota somente leitura executada no Supabase staging `ozvylnaipubrmaadikvk`; nenhuma conta, convite, membership, role ou fator MFA foi criado.
- Baseline remoto comprovado: 3 identidades Auth, 3 profiles, zero profiles ausentes, zero fatores MFA, zero memberships ERP, zero roles ERP e 8 permissões ERP.
- As 7 roles legadas, 3 vínculos legados e 1 atribuição de equipe de plataforma foram preservados; `user_roles` e `erp_membership_roles` permanecem domínios distintos.
- Arquitetura canônica definida como identidade única em `auth.users`, profile em `public.users`, participação multiempresa em `erp_tenant_memberships`, autorização em `erp_membership_roles` e MFA no Supabase Auth.
- Definidas sete personas mínimas: owner de A, owner de B, usuário multiempresa, staff sem membership, usuário suspenso, convidado pendente e privilegiado em AAL1/AAL2.
- Papéis iniciais propostos: `owner`, `admin`, `manager`, `operator` e `viewer`, sempre vinculados à membership do tenant.
- Provisionamento futuro especificado como workflow server-only, idempotente, retomável e dirigido por manifesto; nenhum `service_role` poderá chegar ao navegador.
- E-mails sintéticos em domínios de clientes foram proibidos. Automação efêmera usará `.invalid`; UAT persistente exigirá alias controlado e alcançável da ConnectionCyber.
- Produção exigirá convite para endereço real, recuperação funcional e MFA para funções privilegiadas; nenhuma senha legada será migrada.
- Riscos críticos identificados: confiança em `raw_user_meta_data`, fallback automático para o tenant ConnectionCyber, JWT de tenant único, política de senha fraca, TOTP desligado, `search_path` mutável e policies de profiles concedidas ao pseudo-papel `public`.
- Próxima etapa permanece somente de código e especificação: migration 0018, provisionador em dry-run, telas e testes; Supabase remoto continuará inalterado até novo aceite.
- Checkpoint `bbdc6cc` publicado somente em `origin/staging`; Quality Gates `32210191254` aprovados em `site`, `platform` e `portal`, Vercel `success` e Preview HTTP 200.
- Branch `main` preservada em `59a3924`; pastas de referência permaneceram fora do commit.

### 5.9 M04-G1 — migration, dry-run, telas e testes validados localmente

- Migration `0018_identity_rbac_mfa_hardening.sql` apresentada sem aplicação remota; SHA-256 `e8bf56d6…91e659`.
- `users.tenant_id` passa a compatibilidade nullable; metadata/fallback/JWT deixam de conceder tenant; memberships permanecem autoridade ERP.
- Policies do profile limitam authenticated a leitura própria e atualização somente de nome/idioma.
- Lifecycle de membership, roles com `requires_mfa`, cinco permissões M04 e helpers AAL1/AAL2 foram especificados.
- Ledgers `erp_identity_provisioning_runs/steps` são server-only, idempotentes, retomáveis e recusam chaves de segredo em JSON.
- Provisionador entregue sem modo apply: `executable=false`, `networkCalls=0`, `databaseWrites=0`, sete personas `.invalid` e chave idempotente determinística.
- Tela interna `/identidades` apresenta convite, usuários/memberships, cinco papéis e fluxo AAL1 → TOTP → AAL2; controles de escrita permanecem desabilitados.
- Testes do provisionador: 9/9; TypeScript, ESLint e build Next.js aprovados; rota `/identidades` presente no build.
- Laboratório PostgreSQL 17.6: M02 38/38, M03 35/35 e M04 49/49; segunda passagem M04 após rollback/rebuild também 49/49.
- Rollback recusou execução sem confirmações, removeu somente M04 no laboratório vazio e preservou M03; preflight retornou `M04_PREFLIGHT_OK`.
- Primeira compilação local detectou `auth.jwt()` indisponível; a transação reverteu, o helper passou a usar claims portáveis e toda a suíte foi repetida.
- Fixtures M02/M03 foram tornadas compatíveis com o hardening sem reduzir isolamento ou critérios anteriores.
- Pós-testes: zero runs, steps, identidades, memberships ou roles sintéticas; contêiner descartável removido.
- Inspeção visual automatizada ao vivo não foi concluída por falha interna do recurso de navegador; nenhuma aprovação visual foi presumida.
- Pacote detalhado em `PACOTE-TECNICO-M04-G1-IDENTIDADE-RBAC-MFA.md` e `.html`.
- Checkpoint `72b1e0a` publicado somente em `origin/staging`; Quality Gates `32212844513` concluídos com `site`, `platform` e `portal` aprovados.
- Vercel Preview `dpl_DKNCxPwYHidoC1mmdYNcwjP3YEB4` em estado `Ready`; alias staging HTTP 200; configurações Vercel e DNS inalteradas.
- Branch `main` preservada em `59a3924`; Supabase remoto, Auth, produção e dados reais permaneceram inalterados; zero contas, convites, roles ou fatores MFA criados.

### 5.10 M04-G2 — 0018 aplicada em staging; hardening RLS preparado

- Em 26/08/2026, autorização explícita recebida para aplicar somente a migration `0018` no Supabase staging `ozvylnaipubrmaadikvk`, sem criar contas reais.
- Preflight remoto retornou `M04_PREFLIGHT_OK`; o dry-run selecionou exclusivamente `0018_identity_rbac_mfa_hardening.sql`.
- Migration 0018 aplicada com sucesso; histórico remoto sincronizado de `0001` a `0018`.
- Pós-validação: 3 identidades Auth, 3 profiles, zero memberships, zero roles e zero registros nos ledgers de provisionamento; helpers AAL presentes.
- Plataforma: 9/9 testes; site: 5/5 testes; type-check, lint e builds aprovados; produção permaneceu intocada.
- Advisor de segurança revelou dívida crítica anterior: 16 tabelas legadas públicas sem RLS.
- Migration `0019_harden_legacy_public_rls.sql`, preflight, rollback protegido e 21 testes pgTAP preparados somente no clone staging.
- Dry-run remoto da 0019 confirmou que ela é a única migration pendente; aplicação remota permanece bloqueada até autorização específica.
- Evidência detalhada: `EVIDENCIA-M04-G2-HARDENING-RLS.md`.
- Autorização da 0019 recebida; primeira tentativa falhou de forma transacional por referência à coluna inexistente `products.ativo`, sem efeito parcial.
- Política corrigida para `products.status = 'ativo'`; preflight e dry-run repetidos; migration 0019 aplicada com sucesso.
- Pós-validação da 0019: 16/16 tabelas protegidas, zero alertas `rls_disabled_in_public`, seis políticas esperadas e nenhuma identidade/dado criado.
- Migration `0020_harden_legacy_functions.sql` preparada para corrigir `search_path` de trigger e retirar acesso anônimo de `is_platform_staff()`; aplicação remota pendente.
- Autorização da 0020 recebida; preflight e dry-run selecionaram exclusivamente a migration; aplicação concluída no staging.
- Pós-validação da 0020: `search_path` vazio, `anon` sem EXECUTE em `is_platform_staff()`, authenticated/service_role preservados e histórico `0001–0020` sincronizado.
- Advisor final: zero erros de RLS, zero `search_path` mutável e zero acesso anônimo indevido ao painel; proteção contra senhas vazadas permanece como portão manual do Auth staging.
- Dashboard Supabase acessado via GitHub; proteção contra senhas vazadas confirmada como recurso exclusivo do plano Pro+, indisponível no staging Free; nenhum upgrade realizado.
- Limitação aceita somente para desenvolvimento; plano compatível ou controle compensatório permanece obrigatório antes do piloto/produção.
- Vercel `connectioncyberso/connectioncyber` acessada via GitHub; produção `Ready` em `connectioncyber.com.br`; nenhuma configuração ou deployment alterado.

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
| R-014 | O trigger atual aceita `tenant_id` de `raw_user_meta_data` e usa o tenant ConnectionCyber como fallback. | Crítica | Remover autoridade de metadados do usuário; provisionar membership somente por workflow server-only e recusar contexto ausente. |
| R-015 | Auth staging aceita senha mínima de 6 caracteres, não exige confirmação e está com TOTP desabilitado. | Crítica | Endurecer política, ativação, recuperação e MFA privilegiado por portões testáveis antes de qualquer UAT persistente. |
| R-016 | Endereços sintéticos nos domínios dos clientes podem ser inalcançáveis ou futuramente pertencer a terceiros. | Alta | Usar `.invalid` em automação efêmera e aliases controlados ConnectionCyber em UAT; produção somente com e-mail real confirmado. |

## 7. Programa de módulos e portões

| Ordem | Módulo/portão | Estado atual | Entrega principal | Critério para avançar |
|---:|---|---|---|---|
| M00 | Segurança e qualidade de staging | Aprovado | Migrations, variáveis, CI, Preview e smoke tests aprovados | Concluído e aceito em 18/08/2026. |
| M01 | Arquitetura canônica multissegmento | Aprovado | Núcleo universal, capacidades, catálogo lógico, invariantes e contrato do M02 | Concluído e aceito em 18/08/2026; nenhum schema aplicado. |
| M02 | Fundação ERP multiempresa | Aprovado | Memberships, estabelecimentos, capacidades, configurações, sequências, auditoria e isolamento | Concluído e aceito em 18/08/2026; 0016 permanece somente em staging. |
| M03 | Portal do cliente e subdomínios | Aprovado | `apps/portal`, autenticação e resolução segura de hostname | Concluído e aceito em 18/08/2026; 0017 permanece somente em staging. |
| M04 | Usuários, RBAC e MFA | Aprovado em staging | Identidade, memberships, papéis, convites, recuperação, MFA e hardening | 0018–0020 aplicadas e validadas exclusivamente em staging. |
| M05 | Cadastros e catálogo universal | Aplicado e validado em staging | Pessoas, produtos, serviços, peças, ingredientes, variações, unidades e composições | 0021 aplicada; 44/44 asserções aprovadas; zero dados reais. |
| M06 | Preços, estoque e compras | Aplicado e validado em staging | Listas, depósitos, movimentos, inventário, lotes, séries e pedidos | 0022 aplicada; 48/48 asserções aprovadas; zero dados reais. |
| M07 | Vendas, orçamento e PDV | Aplicado e validado em staging | Orçamentos, vendas, pagamentos, caixa e comprovantes | 0023 aplicada; 52/52 asserções aprovadas; zero dados reais. |
| M08 | Financeiro e bancário | Aplicado e validado em staging | Receber, pagar, fluxo de caixa, cartões, cheques e boletos | 0024 aplicada; 64/64 asserções aprovadas; zero dados reais. |
| M09 | Serviços e oficinas | Aplicado e validado em staging | Ativos, veículos, agenda, OS, peças, mão de obra e histórico | 0025 aplicada; 68/68 asserções aprovadas; zero dados reais. |
| M10 | Restaurantes e lanchonetes | Aplicado e validado em staging | Receitas, adicionais, mesas, comandas e cozinha | 0026 aplicada; 72/72 asserções aprovadas; zero dados reais. |
| M11 | Atendimento e acesso remoto | Aplicado e validado em staging | Tickets, SLA, dispositivos, consentimentos, sessões e auditoria | 0028 aplicada; 87/87 asserções aprovadas; zero dados reais. |
| M12 | Agente local e periféricos | Aplicado e validado em staging | Impressão, etiqueta, balança, TEF e contingência/offline | 0029 aplicada; 84/84 asserções aprovadas; 12 tabelas com RLS e zero dados reais. |
| M13 | Fiscal e certificado A1 | Motor global validado; piloto pendente | Contratos, schemas, assinatura, estados, SOAP/TLS e perfis tributários fail-closed | Retomar validação individual após confirmação do contador em 31/08/2026; emissão real permanece bloqueada. |
| M14 | Engenharia reversa e importador | Fundação concluída em staging | Laboratório, adaptadores, lotes, mapa de IDs e reconciliação | 0031 aplicada; 96/96 pós-aplicação; execução com fonte real transferida aos portões individuais do M15. |
| M15 | Piloto e implantação por cliente | G0–G11 concluídos em staging | Jornada visual sintética consolidada (cadastro→catálogo→estoque→PDV→caixa→financeiro) e preparação local de hipercare | Sintético/local encerrado; depende do M18 para persistência real. UAT com usuário real e produção seguem bloqueados. |
| M16 | Capacidades por tenant e industrialização multiempresa | G0–G8 concluídos em staging | Contrato canônico de capacidades, motor fail-closed, migration 0032, painel administrativo e simulador de ondas | 0032 aplicada e validada em staging; ativação de capacidade por tenant real depende do piloto. |
| M17 | Jornada persistente server-side | G0–G12 concluídos em staging | Autorização server-side, cadastro/catálogo/estoque/PDV/caixa/financeiro com repositório local, migration 0033 | 0033 aplicada e validada em staging; backend persistente pronto, consumido pelo M18. |
| M18 | Persistência visual e piloto Mania de Modas | G0–G21 concluídos em staging; **G22 parcialmente concluído** | Fronteira visual local→persistente, adaptador Supabase, agregados, migration 0034, provisionamento do tenant piloto (Mania de Modas) | 0034 aplicada; tenant/estabelecimento/membership/convite criados em staging (`M18_G21_PROVISIONING_OK`). G22: convite aceito, senha definida, `erp_tenant_memberships.status='active'` confirmado no banco, login real ponta a ponta validado (04/09/2026, dois incidentes de vazamento de token corrigidos no processo). Tela de cadastro/step-up de MFA (`/configuracoes/seguranca`) implementada e validada localmente (86/86, type-check/lint/build limpos) — ainda não publicada nem usada pelo piloto. Falta: push pro remoto, deploy, owner cadastrar MFA/TOTP de verdade, validar sessão AAL2 e executar a primeira jornada visual real — sem isso o portão não fecha. |
| M19 | Redesign visual + roteamento de login | **G0–G5 concluídos** | Tema global/dark mode (G1), redesign do painel (G2), branding por tenant (G3, migration 0035 aplicada), engrenagem de branding no portal (G4), roteamento de login por papel sem lookup de e-mail (G5) | Programa concluído. `platform` 165/165, `portal` 75/75, `site` 19/19; type-check/lint/build limpos nos 3. Uma migration nova (0035), aplicada em staging com preflight+dry-run+push. |

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

### M19 — concluído (G0–G5)

Plano executado conforme aprovado pelo usuário em 02-03/09/2026
(`C:\Users\joaqu\.claude\plans\keen-growing-cookie.md`, fora do repositório). Sem próxima ação
pendente neste programa — eventual redesign bespoke por tela individual do `apps/platform`
(fora de escopo do G2) ou upload de logo via Storage (fora de escopo do G4) ficam para um
portão futuro, só se solicitados.

### M18-G22 — ativação controlada do acesso do usuário-piloto (parcialmente concluído, ação externa restante)

Único portão pendente no momento — independente do M19, que está concluído.

Definido em `RELATORIO-M18-G21-PROVISIONAMENTO-PILOTO-STAGING.md` como próximo portão após o
provisionamento do tenant Mania de Modas (`M18_G21_PROVISIONING_OK`). Depende de interação do
usuário convidado, não é automatizável:

1. ✅ convite Auth entregue e aceito pelo usuário-piloto (após corrigir e-mail errado e dois
   incidentes de vazamento de token no processo de entrega — ambos revogados imediatamente e
   corrigidos na raiz, ver seções "Incidente e correção" e "Incidente e correção 2" acima);
2. ✅ usuário-piloto concluiu o cadastro de senha; `erp_tenant_memberships.status='active'`
   confirmado no banco; login real ponta a ponta testado e confirmado por print
   (04/09/2026) — dashboard do portal mostra "Empresa ativa: Mania de Modas", "Contexto
   validado";
3. 🔶 tela de cadastro de MFA implementada e validada localmente
   (`/configuracoes/seguranca`, ver seção "tela de MFA/TOTP implementada" acima) — **falta o
   usuário-piloto de fato escanear o QR e confirmar o código em staging**;
4. 🔶 gate automático redireciona qualquer sessão `aal1` do `owner` pra lá antes de qualquer
   módulo — implementado e testado (`decideMfaGate`, 86/86) — **falta a validação AAL2 real
   acontecer**, depende do item 3;
5. ⬜ executar a primeira jornada visual (leitura) com a sessão real, ainda somente em
   staging — **não confirmado ainda**.

Portão fecha quando 3–5 forem confirmados. Importação de backup real, dados fiscais, domínio
público, pagamentos e produção permanecem em
portões separados e bloqueados.

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
| 1.9.0 | 18/08/2026 | M03 | Parecer aprovado; `apps/portal`, migration 0017, preflight, rollback, 19 testes unitários, 35 asserções pgTAP e job CI apresentados. | Aplicação compilada e inspecionada localmente; SQL ainda não executado; aguarda aceite para laboratório local descartável. |
| 1.9.1 | 18/08/2026 | M03 | Checkpoint `285d103`, Quality Gates `32203034263` e Preview staging registrados. | `site`, `platform` e `portal` aprovados; HTTP 200; 0017 permanece não executada. |
| 2.0.0 | 18/08/2026 | M03 | Preflight, dry-run exclusivo, 0017 local, rollback protegido, reconstrução e duas passagens 35/35. | Validado localmente com zero resíduos; Supabase remoto e produção inalterados. |
| 2.0.1 | 18/08/2026 | M03 | Checkpoint `563a669`, Quality Gates `32204837889`, Vercel success e Preview HTTP 200 registrados. | Evidências publicadas em staging; 0017 continua ausente no Supabase remoto. |
| 2.1.0 | 18/08/2026 | M03 | Preflight e dry-run remotos, aplicação exclusiva da 0017 em staging, histórico, estrutura, grants, RLS, policies, lint, 35 pgTAP e resíduos verificados. | Validado em staging com 35/35 e zero fixtures; produção, Vercel, DNS e dados reais intocados; aguarda aceite formal do M03. |
| 2.1.1 | 18/08/2026 | M03 | Checkpoint `0111056`, Quality Gates `32206753538`, status Vercel e Preview HTTP 200 registrados. | `site`, `platform` e `portal` aprovados; `main` permaneceu em `59a3924`; M03 aguarda aceite formal. |
| 2.2.0 | 18/08/2026 | M04-G0 | M03 aprovado; identidade, sete personas, papéis, MFA, manifesto, provisionamento idempotente, riscos e testes do M04 especificados. | Parecer apresentado sem criar contas, convites, memberships, roles ou fatores MFA e sem alterar Supabase remoto, Vercel, DNS ou produção. |
| 2.2.1 | 18/08/2026 | M04-G0 | Checkpoint `bbdc6cc`, Quality Gates `32210191254`, Vercel e Preview registrados. | `site`, `platform` e `portal` aprovados; HTTP 200; `main` preservada; nenhuma conta ou migration remota criada. |
| 2.3.0 | 19/08/2026 | M04-G1 | Migration 0018, preflight, rollback, dry-run, sete personas, quatro telas, 9 testes Node e 49 pgTAP apresentados. | M02 38/38, M03 35/35, M04 49/49 e rebuild 49/49; build aprovado; zero resíduos; remoto inalterado. |
| 2.3.1 | 19/08/2026 | M04-G1 | Checkpoint `72b1e0a`, Quality Gates `32212844513`, deployment Vercel e Preview HTTP 200 registrados. | `site`, `platform` e `portal` aprovados; `main` preservada; 0018 não aplicada e zero identidades criadas. |
| 2.4.0 | 26/08/2026 | M05-G1 | Cadastros, catálogo universal, migration 0021, preflight, rollback, telas e 44 pgTAP apresentados. | Código local, type-check, ESLint e dry-run aprovados; 0021 permanece não aplicada e produção intocada. |
| 2.5.0 | 26/08/2026 | M05-G2 | Migration 0021 aplicada exclusivamente em staging; histórico, grants, RLS, contagens e 44 pgTAP validados. | 44/44 aprovados, zero registros M05, banco sem migrations pendentes e produção intocada. |
| 2.6.0 | 26/08/2026 | M06-G0 | M05 aprovado por continuidade; preços, estoque, compras, concorrência, idempotência e fronteiras documentados. | Parecer concluído; nenhuma migration M06 aplicada, nenhum dado criado e produção intocada. |
| 2.7.0 | 26/08/2026 | M06-G1 | Migration 0022, preflight, rollback, 48 testes e visão `/operacoes` preparados. | Testes, TypeScript, ESLint, preflight e dry-run aprovados; 0022 não aplicada e produção intocada. |
| 2.8.0 | 26/08/2026 | M06-G2 | Migration 0022 validada com rollback, aplicada somente em staging e verificada com 48 asserções. | 48/48 aprovados, zero registros M06, histórico alinhado e produção intocada. |
| 2.9.0 | 26/08/2026 | M07-G0 | M06 aprovado por continuidade; vendas, orçamento, PDV, pagamentos, caixa, concorrência e limites fiscal/financeiro documentados. | Parecer concluído; nenhuma migration M07 aplicada, nenhuma conta ou venda criada e produção intocada. |
| 3.0.0 | 27/08/2026 | M07-G1 | Migration 0023, preflight, rollback, 52 testes, fechamento atômico e telas `/vendas` e `/pdv` preparados. | Testes, TypeScript, ESLint, preflight e dry-run aprovados; 0023 não aplicada e produção intocada. |
| 3.1.0 | 27/08/2026 | M07-G2 | Migration 0023 validada com rollback, aplicada somente em staging e verificada com 52 asserções. | 52/52 aprovados, zero registros M07, histórico alinhado e produção intocada. |
| 3.2.0 | 27/08/2026 | M08-G0 | M07 aprovado por continuidade; títulos, parcelas, liquidações, bancos, cartões, cheques, boletos e conciliação documentados. | Parecer concluído; nenhuma migration M08 aplicada, nenhuma conta ou transação criada e produção intocada. |
| 3.3.0 | 27/08/2026 | M08-G1 | Migration 0024, três RPCs, preflight, rollback, 64 testes e telas `/financeiro` e `/bancos` preparados. | Testes, TypeScript, ESLint, preflight e dry-run aprovados; 0024 não aplicada e produção intocada. |
| 3.4.0 | 27/08/2026 | M08-G2 | Migration 0024 validada com rollback, aplicada somente em staging e verificada com 64 asserções. | 64/64 aprovados, zero registros M08, histórico alinhado e produção intocada. |
| 3.5.0 | 27/08/2026 | M09-G0 | M08 aprovado por continuidade; ativos, veículos, agenda, OS, inspeção, autorização, garantia e fechamento integrado documentados. | Parecer concluído; nenhuma migration M09 aplicada, nenhum ativo ou OS criado e produção intocada. |
| 3.6.0 | 27/08/2026 | M09-G1 | Migration 0025, duas RPCs, preflight, rollback, 68 testes e tela `/servicos` preparados. | TypeScript, ESLint e 9/9 testes Node aprovados; execução SQL e aplicação remota não iniciadas; produção intocada. |
| 3.7.0 | 27/08/2026 | M09-G2 | Preflight, dry-run e migration 0025 executados exclusivamente no Supabase staging; histórico, RLS, grants, objetos e contagens auditados. | 68/68 aprovados, zero registros M09, banco sem migrations pendentes e produção intocada. |
| 3.8.0 | 27/08/2026 | M10-G0 | M09 aprovado por continuidade; receitas, adicionais, salão, comandas, cozinha, rateio e fechamento integrado documentados. | Parecer concluído; nenhuma migration M10 aplicada, nenhuma comanda ou venda criada e produção intocada. |
| 3.9.0 | 27/08/2026 | M10-G1 | Migration 0026, duas RPCs, preflight, rollback, 72 testes e tela `/alimentacao` preparados. | TypeScript, ESLint e 9/9 testes Node aprovados; execução SQL e aplicação remota não iniciadas; produção intocada. |
| 4.0.0 | 27/08/2026 | M10-G2 | Delimitadores SQL corrigidos após bloqueio seguro do primeiro preflight; preflight, dry-run e migration 0026 executados exclusivamente no staging. | 72/72 aprovados, zero registros M10, histórico alinhado, banco sem migrations pendentes e produção intocada. |
| 4.1.0 | 27/08/2026 | M11-G0 | M10 aprovado por continuidade; tickets, SLA, filas, dispositivos, consentimento, grants efêmeros, sessões e auditoria documentados. | Parecer concluído; nenhuma migration M11 aplicada, nenhum ticket, grant ou sessão criado e produção intocada. |
| 4.2.0 | 27/08/2026 | M11-G1 | Inventário global analisado; migration M11 renumerada para 0028 devido à 0027 CTR paralela; três RPCs, preflight, rollback, 76 testes e tela `/atendimento` preparados. | TypeScript, ESLint e 9/9 testes Node aprovados; 0027 CTR preservada e não versionada; execução SQL e aplicação remota não iniciadas; produção intocada. |
| 4.3.0 | 27/08/2026 | CTR-0027-G0 | Migration, mudanças de catálogo, padrão e spec CTR auditados sem alteração dos arquivos paralelos. | Reprovada para aplicação: vetor placeholder, pacote sem portões, pgvector não qualificado, RPC sem limites e ausência de proveniência; remoto e produção intocados. |
| 4.4.0 | 27/08/2026 | CTR-0027-G1 | Placeholder removido; migration, fallback lexical, RRF, privilégios server-only, preflight, rollback e 36 testes preparados. | TypeScript, ESLint e 9/9 testes Node aprovados; SQL remoto não executado, embeddings reais desabilitados e produção intocada. |
| 5.4.0 | 29/08/2026 | M13-G17 | Preflight individual fail-closed da primeira NF-e modelo 55 e 19 novos testes preparados. | 209/209 aprovados; 13 requisitos ausentes bloqueados; nenhum XML, assinatura, transmissão, Supabase remoto ou produção. |
| 5.5.0 | 29/08/2026 | M13-G18 | Coletor protegido em memória, validações cruzadas e oito testes adicionais preparados. | 217/217 e parser PowerShell aprovados; coleta real não executada; zero persistência, XML, assinatura, transmissão ou produção. |
| 5.6.0 | 29/08/2026 | M13-G19 | Quatro perfis sintéticos, resolução por tenant e validação fail-closed de CRT, CST/CSOSN, NCM, CFOP e versão. | 234/234 aprovados; RPA com CSOSN e produção bloqueados; empresa-piloto pendente de contador. |
| 5.7.0 | 29/08/2026 | M14-G0 | Pipeline determinístico de importação, invariantes, riscos e portões definidos. | Contratos e simuladores liberados; backup, credenciais e dados reais permanecem bloqueados. |
| 5.8.0 | 29/08/2026 | M14-G1 | Manifesto SHA-256, lote canônico, dez domínios e simulador atômico/idempotente implementados. | 24/24 aprovados; reconciliação prévia, isolamento recursivo e replay comprovados; zero fonte real ou persistência. |
| 5.9.0 | 29/08/2026 | M14-G2 | Migration 0031, sete tabelas, cinco RPCs server-only, RLS, preflight, rollback e 80 pgTAP preparados e executados localmente. | Constraint longa nomeada; 37/37, preflight, 80/80, rollback, zero resíduos, rebuild e 80/80; remoto e produção intocados. |
| 6.0.0 | 29/08/2026 | M14-G3 | Auditoria de concorrência, idempotência, FKs, estados, metadados e reconciliação da 0031. | Reprovada para remoto com sete bloqueios; nenhuma alteração SQL, dado real ou acesso à produção. |
| 6.1.0 | 29/08/2026 | M14-G4 | Sete bloqueios da 0031 remediados; concorrência serializada, FKs compostas, estados fail-closed, allowlists e reconciliação durável implementados. | 41/41 e dois ciclos 96/96 aprovados; rollback e preflight repetidos; remoto e produção intocados; aguarda auditoria M14-G5. |
| 6.2.0 | 29/08/2026 | M14-G5 | Auditoria final independente de escopo, concorrência, integridade, RLS, privilégios, rollback e resíduos da 0031. | Aprovada para preflight e validação transacional remota com ROLLBACK; 41/41, 96/96, 7/7 RLS, 5/5 RPCs e zero dados; aplicação persistente bloqueada. |
| 6.3.0 | 29/08/2026 | M14-G6 | Dry-run exclusivo, preflight e validação fail-closed da 0031 no Supabase staging dentro de transação com ROLLBACK. | 96/96 aprovados; histórico remoto permanece em 0030; preflight final confirmou zero resíduos; produção intocada e aplicação persistente bloqueada. |
| 6.4.0 | 29/08/2026 | M14-G7 | Migration 0031 aplicada persistentemente apenas no Supabase staging e auditada pelo fluxo pós-aplicação fail-closed. | 96/96, auditoria estrutural, histórico 0031/0031, dry-run sem pendências e zero dados; produção intocada. |
| 6.5.0 | 29/08/2026 | M14-G8 | Fundação global do importador encerrada e pendências dependentes de fonte real transferidas para portões individuais do piloto. | M14 concluído em staging; M15 definido como próximo módulo; M15-G0 liberado sem dados reais e corte fiscal/produção bloqueado. |
| 6.6.0 | 29/08/2026 | M15-G0 | Matriz de prontidão, riscos, critérios de aceite e onze portões determinísticos definidos para a Mania de Moda. | Preparação sintética liberada; UAT real e produção bloqueadas até segurança, backup, fiscal, dispositivos, fonte e operação serem aprovados. |
| 6.7.0 | 30/08/2026 | M15-G1 | Baseline local auditada em Auth, MFA, rede, segredos, dependências, CI/CD, headers, backup, observabilidade e runbooks. | 316 testes e zero vulnerabilidades runtime; 5 críticos, 6 altos e 4 médios; UAT real reprovada e remediação local R1 liberada. |
| 6.8.0 | 30/08/2026 | M15-G1-R1 | Headers compartilhados, redirect fail-closed, Node 22, CI expandido, seeds opt-in e três runbooks implementados. | 337/337, TypeScript, ESLint e três builds aprovados; M15-G2 sintético liberado; remoto e produção intocados. |

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
## M15-G2 — jornada sintética ponta a ponta (30/08/2026)

- `M15_G2_SYNTHETIC_JOURNEY_OK`.
- MEI, ME e LTDA sintéticos validados.
- Autenticação, MFA, membership, papéis e cross-tenant aprovados.
- Cadastro, catálogo, estoque, venda, caixa e financeiro exercitados.
- Fiscal bloqueado por padrão e rollback com zero registros remanescentes.
- Supabase remoto e produção não acessados.
## M15-G3 — preparação do ensaio integrado (30/08/2026)

- Preflight e ensaio pgTAP local preparados.
- MEI, ME e LTDA exclusivamente sintéticos; 30 asserções planejadas.
- Cadastro, catálogo, estoque, venda, caixa, financeiro, RLS e cross-tenant cobertos.
- Fiscal fail-closed, nenhuma conta e `ROLLBACK` obrigatório.
- Execução remota bloqueada até autorização específica.
- Execução posteriormente autorizada e aprovada: `M15_G3_PREFLIGHT_OK`, 30 asserções e `M15_G3_ROLLBACK_CLEAN`.
- Resíduos após rollback: 0 tenants, 0 contas e 0 documentos fiscais.
## M15-G4 — primeiro fluxo visual (30/08/2026)

- Dashboard local `/demo` criado com dados exclusivamente sintéticos.
- Perfis MEI, ME e LTDA alternáveis; capacidades e indicadores mudam por perfil.
- Cadastros, estoque, vendas/PDV, caixa e financeiro navegáveis.
- 24/24 testes, TypeScript, ESLint, build, desktop e celular aprovados.
- Supabase remoto, Vercel e produção não alterados.
## M15-G5 — PDV visual sintético (30/08/2026)

- Fluxo completo de venda disponível em `/demo` → “Nova venda”.
- Busca, catálogo, carrinho, estoque, desconto, pagamento e comprovante implementados.
- 31/31 testes, TypeScript, ESLint, build, desktop e celular aprovados.
- Estado somente em memória; Supabase remoto, pagamentos, fiscal e produção intocados.
## M15-G6 — cadastros integrados ao PDV (30/08/2026)

- Fluxos visuais de cliente e produto sintéticos implementados em `/demo`.
- Estado compartilhado somente em memória; novos cadastros alimentam imediatamente o PDV.
- Cliente selecionável na venda e produto pesquisável no catálogo.
- 37/37 testes, TypeScript e ESLint aprovados.
- Runtime normalizado em Node.js 22.23.2; build Next.js aprovado.
- Desktop e celular 390 × 844 aprovados; sem rolagem horizontal.
- Marcador final: `M15_G6_VISUAL_INTEGRATION_OK`.
- Supabase remoto, Vercel e produção não acessados.
## M15-G7 — estoque visual integrado (30/08/2026)

- Entrada, saída, ledger sintético e bloqueio de saldo negativo implementados.
- Saldo compartilhado em memória e refletido imediatamente no PDV.
- 41/41 testes, TypeScript, ESLint, build, desktop e celular aprovados com Node.js 22.23.2.
- Marcador: `M15_G7_INVENTORY_VISUAL_OK`.
- Supabase remoto, Vercel e produção não acessados.
## M15-G8 — caixa visual integrado (30/08/2026)

- Abertura, entradas, saídas, vendas automáticas e fechamento conferido implementados em memória.
- PDV bloqueado com caixa fechado; diferença de fechamento bloqueada.
- 46/46 testes, TypeScript, ESLint, build, desktop e celular aprovados com Node.js 22.23.2.
- Marcador: `M15_G8_CASH_VISUAL_OK`.
- Supabase remoto, Vercel, pagamentos e produção não acessados.
## M15-G9 — financeiro visual integrado (30/08/2026)

- Contas a pagar/receber, vencimentos, baixa e filtros implementados em memória.
- Baixas exigem caixa aberto; pagamentos respeitam o saldo disponível.
- 51/51 testes, TypeScript, ESLint, build, desktop e celular aprovados com Node.js 22.23.2.
- Marcador: `M15_G9_FINANCE_VISUAL_OK`.
- Supabase remoto, Vercel, bancos, pagamentos e produção não acessados.
## M15-G10 — jornada visual consolidada (30/08/2026)

- Dashboard conectado às vendas, estoque, caixa e financeiro da sessão.
- Indicadores e alertas são recalculados após cada operação sintética.
- Estado financeiro preservado durante a navegação entre módulos.
- 56/56 testes, TypeScript, ESLint e build aprovados com Node.js 22.23.2.
- Marcador: `M15_G10_CONSOLIDATED_JOURNEY_OK`.
- Supabase remoto, Vercel, bancos, fiscal e produção não acessados.
## M15-G11 — preparação local de hipercare (30/08/2026)

- Próximo gate cronológico confirmado no parecer M15-G0.
- Contrato de métricas, alertas SEV-1/SEV-2, simulador e critérios de aceite preparados localmente.
- Aceite final e hipercare real continuam bloqueados até corte autorizado.
- Marcador: `M15_G11_LOCAL_PREPARATION_OK`.
- Serviços remotos e produção não acessados.
## M16-G0 — industrialização multiempresa (30/08/2026)

- Nenhum gate formal existia depois do M15-G11; o parecer cronológico foi emitido antes de avançar.
- M15 operacional real permanece bloqueado até UAT, corte e acompanhamento autorizados.
- M16 definido como trilha local para núcleo único, capacidades por tenant e rollout em ondas.
- Sequência M16-G1 a M16-G8 registrada com portões remotos explícitos.
- Marcador: `M16_G0_MULTI_TENANT_PRODUCTIZATION_APPROVED`.
- Próximo gate local: M16-G1, contrato canônico de capacidades, planos e exceções.
## M16-G1 — contrato canônico de capacidades (30/08/2026)

- Catálogo, blueprints MEI/ME/LTDA e exceções temporárias auditáveis implementados localmente.
- Resolução determinística e fail-closed, sem condicionais por cliente real.
- Simulador e testes usam somente tenants sintéticos.
- 20/20 testes aprovados com Node.js 22.23.2.
- Marcador: `M16_G1_CAPABILITY_CONTRACT_OK`.
- Banco, Supabase, Vercel, GitHub e produção não acessados.
## M16-G2 — motor fail-closed e matriz empresarial (30/08/2026)

- Estados enabled, disabled e blocked resolvidos deterministicamente.
- Dependências e prontidão operacional impedem liberações implícitas.
- Matriz sintética MEI/ME/LTDA implementada sem banco ou rede.
- 37/37 testes aprovados com Node.js 22.23.2.
- Marcador: `M16_G2_FAIL_CLOSED_ENGINE_OK`.
- Serviços remotos e produção não acessados.
- Próximo gate: M16-G3, migration local `0032`; aplicação remota bloqueada.
## M16-G3 — migration local 0032 (30/08/2026)

- Catálogo, entitlements, exceções tenant-scoped, RLS e resolver protegidos preparados localmente.
- Preflight `M16_G3_PREFLIGHT_OK` e pgTAP ampliado para 60 asserções com rollback obrigatório.
- 54/54 testes locais aprovados; SHA-256 normalizado `237485033a7484147315adeda8184b837298e55982c9741f86cd9e7418c7e3f3`.
- Marcador: `M16_G3_MIGRATION_0032_LOCAL_READY`.
- Migration não aplicada em banco; próximo gate é auditoria local M16-G4.
## M16-G4 — auditoria e remediação da 0032 (30/08/2026)

- Privilégios do service_role reduzidos; catálogo não pode ser alterado pelo broker.
- Aprovação agora aceita somente referência SHA-256 opaca.
- Revogação broker-only idempotente e testes reais do resolver adicionados.
- 54/54 testes locais e 60 asserções pgTAP preparados.
- Marcador: `M16_G4_MIGRATION_0032_AUDITED_READY`.
- Próximo portão remoto: M16-G5 com preflight e rollback; aplicação persistente bloqueada.
## M16-G5 — validação transacional remota da 0032 (31/08/2026)

- Preflight final aprovado após compatibilização com catálogo e entitlements canônicos da 0016.
- Dry-run confirmou somente a 0032; 60/60 asserções remotas aprovadas dentro de transação.
- ROLLBACK confirmado: histórico, tabela, colunas, RPCs, permissão e fixtures ausentes.
- Marcador: `M16_G5_0032_TRANSACTION_ROLLBACK_OK`.
- Produção não acessada e aplicação persistente continua bloqueada.
## M16-G6 — aplicação persistente da 0032 no staging (31/08/2026)

- Preflight e dry-run confirmaram exclusivamente a 0032.
- Migration aplicada no Supabase staging `ozvylnaipubrmaadikvk`.
- 60/60 asserções remotas aprovadas; RLS, RPCs e privilégios mínimos confirmados.
- Zero exceções, fixtures, contas ou dados reais.
- Histórico alinhado até 0032 e dry-run final sem pendências.
- Marcador: `M16_G6_0032_STAGING_APPLIED_OK`.
- Produção não acessada.
## M16-G7 — painel administrativo local de capacidades (31/08/2026)

- Rota protegida `/capacidades` adicionada ao painel interno.
- Perfis sintéticos MEI, ME e LTDA exibem 12 capacidades canônicas e prontidão crítica.
- Exceções allow/deny/revoke funcionam somente em memória, com bloqueio prevalecendo em conflito.
- 20/20 testes, TypeScript, ESLint e build aprovados com Node.js 22.23.2.
- Marcador: `M16_G7_CAPABILITY_ADMIN_DEMO_OK`.
- Supabase, Vercel, GitHub remoto e produção não acessados.
- Próximo gate local: M16-G8, simulador de implantação em ondas e rollback por tenant.
## M16-G8 — simulador local de implantação em ondas (31/08/2026)

- Rota protegida `/implantacao` adicionada ao painel interno.
- Ondas laboratório, canário, coorte e concluída possuem promoção determinística e fail-closed.
- Critérios incluem volume, erros, latência, isolamento cross-tenant e prontidão de rollback.
- Rollback sintético reverte somente a empresa selecionada para sua release anterior.
- 32/32 testes, TypeScript, ESLint e build aprovados com Node.js 22.23.2.
- Marcador: `M16_G8_SYNTHETIC_ROLLOUT_OK`.
- Serviços remotos e produção não acessados; M16 encerrado no escopo planejado.
## M17-G0 — parecer de integração funcional persistente (31/08/2026)

- M16 encerrado: núcleo único, capacidades, migration `0032`, painel e rollout sintético concluídos.
- Lacuna prioritária confirmada entre a jornada visual em memória e o backend multi-tenant persistente.
- M17 definido para integrar cadastro, catálogo, estoque, PDV, caixa e financeiro por contratos server-side e RPCs idempotentes.
- Sequência M17-G1 a M17-G9 separa trabalho local dos portões remotos em staging.
- M15 operacional real permanece suspenso até identidade, fiscal, equipamentos, backup, UAT e aceite do piloto.
- Marcador: `M17_G0_PERSISTENT_FUNCTIONAL_TRACK_APPROVED`.
- Nenhum código funcional, banco ou serviço remoto foi alterado neste parecer.
## M17-G1 — contrato canônico da jornada persistente (31/08/2026)

- Sete comandos e seis máquinas de estado foram formalizados em pacote executável local.
- Tenant, ator, membership e capacidades são contexto exclusivo do servidor; campos de autoridade do navegador são recusados.
- Idempotência, conflito, erros públicos seguros e rollback integral foram implementados.
- Simulador reconciliou cadastro, catálogo, estoque, venda, caixa e financeiro.
- 25/25 testes do contrato e 32/32 testes da plataforma aprovados com Node.js 22.23.2.
- Marcador: `M17_G1_PERSISTENT_JOURNEY_CONTRACT_OK`.
- Banco, Supabase, rede e produção não acessados.
## M17-G2 — autorização server-side com dublês (31/08/2026)

- Host, sessão, tenant, membership, MFA, permissão e capacidade agora compõem uma fronteira de autorização única.
- Os sete comandos possuem política explícita de permissão e capacidade.
- Divergências, capacidades desconhecidas e falhas de dependência permanecem fail-closed.
- Autorizações e negações produzem evidência mínima sem payload ou host.
- 44/44 testes do pacote e regressão completa da plataforma aprovados com Node.js 22.23.2.
- Marcador: `M17_G2_SERVER_AUTHORIZATION_OK`.
- Somente dublês locais; banco, Supabase, rede e produção não acessados.
## M17-G3 — cadastro e catálogo com repositórios locais (31/08/2026)

- Comandos de cadastro e item foram conectados à fronteira server-side M17-G2.
- Unidade de trabalho local reúne repositórios tenant-scoped e inbox idempotente.
- Replay, conflito, duplicidade, isolamento e rollback integral foram comprovados.
- Campos mestres reais são recusados; somente conteúdo explicitamente sintético é aceito.
- 68/68 testes do pacote e regressão completa da plataforma aprovados com Node.js 22.23.2.
- Marcador: `M17_G3_LOCAL_MASTER_DATA_OK`.
- Banco, Supabase, rede e produção não acessados.
## M17-G4 — estoque, PDV e caixa locais (31/08/2026)

- Estoque, movimentos, venda, caixa e inbox foram integrados em unidade de trabalho local.
- Total da venda e snapshot de preço são derivados do catálogo server-side.
- Replay, insuficiência de estoque, falha injetada, diferença de caixa e isolamento foram comprovados.
- Simulação finalizou estoque em 8 unidades e caixa conferido em 7.000 centavos.
- 89/89 testes do pacote e regressão completa da plataforma aprovados com Node.js 22.23.2.
- Marcador: `M17_G4_LOCAL_OPERATIONS_OK`.
- Banco, Supabase, rede e produção não acessados.
## M17-G5 — financeiro derivado e reconciliação local (31/08/2026)

- Venda em dinheiro liquida na origem; venda a prazo cria recebível sem inflar o caixa físico.
- Baixas parciais e integrais são autorizadas no servidor, idempotentes e protegidas contra excesso.
- Reconciliação por tenant fecha vendas, caixa, títulos, liquidações e saldo aberto.
- Falha injetada, replay, conflito e isolamento entre empresas foram comprovados.
- 108/108 testes do pacote e 32/32 testes da plataforma, TypeScript, ESLint e build aprovados.
- Marcador: `M17_G5_LOCAL_FINANCE_RECONCILIATION_OK`.
- Banco, Supabase, rede e produção não acessados.
## M17-G6 — auditoria independente da jornada integrada (31/08/2026)

- Segurança, concorrência, idempotência e rollback dos gates M17-G1 a G5 foram auditados adversarialmente.
- Triagem de campos de autoridade passou a bloquear aliases independentemente de maiúsculas.
- Reconciliação financeira tornou-se atômica e deixou de ser exposta sem autorização.
- Corridas idênticas e divergentes de venda e liquidação foram comprovadas fail-closed.
- 116/116 testes do pacote e 32/32 testes da plataforma, TypeScript, ESLint e build aprovados.
- Marcador: `M17_G6_INDEPENDENT_LOCAL_AUDIT_OK`.
- Banco, Supabase, rede e produção não acessados.
## M17-G7 — contrato de persistência PostgreSQL/Supabase (31/08/2026)

- Contrato `M17-PG-1.0` cobre os sete comandos com RPCs transacionais versionadas.
- Baseline 0021–0024 e 0032 será reutilizada; inbox `erp_command_receipts` foi planejado sem criar migration.
- Locks ordenados, versões otimistas, hash idempotente e rollback integral foram formalizados.
- Vinte invariantes de tenant, RLS, dinheiro, estoque, caixa, financeiro e erros seguros foram fixados.
- 141/141 testes do pacote e 32/32 testes da plataforma, TypeScript, ESLint e build aprovados.
- Marcador: `M17_G7_POSTGRES_PERSISTENCE_CONTRACT_OK`.
- Nenhuma migration criada; banco, Supabase, rede e produção não acessados.
## M17-G8 — migration local 0033 (31/08/2026)

- Inbox transacional, três helpers e sete RPCs versionadas foram materializados localmente.
- SHA-256 do JSONB é recalculado no banco; replay divergente e concorrência falham fechado.
- RLS, privilégios mínimos, preflight, rollback e plano pgTAP de 90 asserções foram preparados.
- 163/163 testes do pacote e 32/32 testes da plataforma, TypeScript, ESLint e build aprovados.
- pgTAP ainda não executado em PostgreSQL porque `psql` e Supabase CLI não estavam disponíveis neste ambiente.
- SHA-256 da migration: `17f7fc7e740d6f11cdfdba86a81c44fc9d057b3a4bec6f5d1800c9daf635284b`.
- Marcador: `M17_G8_MIGRATION_0033_LOCAL_READY`.
- Supabase, rede e produção não acessados; aplicação remota bloqueada.
## M17-G9 — auditoria independente da migration 0033 (31/08/2026)

- Cinco bloqueios foram encontrados e remediados: hash canônico, função criptográfica qualificada, triagem de payload, alvo de estoque e projeção financeira da venda a prazo.
- Crediário integral da loja agora cria título e parcela atomicamente; modalidade mista permanece fail-closed.
- Plano pgTAP ampliado para 96 asserções, ainda sem execução PostgreSQL ou remota.
- 168/168 testes do pacote e 32/32 testes da plataforma, TypeScript, ESLint e `git diff --check` aprovados.
- SHA-256 final confirmado no M17-G10: `f20d6f908a7f8477e5a6dd96cc02b2634451943b9bac70839ba4aa686e848e26`.
- Marcador: `M17_G9_MIGRATION_0033_LOCAL_AUDIT_OK`.
- Supabase, rede e produção não acessados; validação remota bloqueada.
## M17-G10 — validação transacional remota da migration 0033 (31/08/2026)

- Staging confirmado: `ozvylnaipubrmaadikvk`; histórico remoto permaneceu em `0001–0032`.
- Preflight corrigiu fail-closed a localização de `pgcrypto.digest` para o schema `extensions`.
- Marcadores aprovados: `M17_0033_PREFLIGHT_OK` e `M17_0033_TRANSACTION_96_OF_96_ROLLBACK`.
- 96/96 asserções executadas dentro de transação com `ROLLBACK`.
- Prova final confirmou tabela e dez funções ausentes; zero resíduo e zero dados reais.
- Marcador: `M17_G10_0033_TRANSACTION_96_OF_96_ROLLBACK_OK`.
- Produção não acessada; aplicação persistente da `0033` continua bloqueada.
## M17-G11 — aplicação persistente da migration 0033 em staging (31/08/2026)

- Dry-run confirmou exclusivamente `0033_m17_persistent_journey.sql`, sem seeds ou roles.
- Migration registrada como `0033/0033` no Supabase staging `ozvylnaipubrmaadikvk`.
- 96/96 asserções pós-aplicação aprovadas em transação com `ROLLBACK`.
- RLS ativo, dez funções presentes, zero receipts e privilégios mínimos confirmados.
- Marcador: `M17_G11_0033_STAGING_96_OF_96_OK`.
- Produção não acessada e nenhum dado real criado.
## M17-G12 — encerramento do backend persistente e definição do M18 (31/08/2026)

- M17 encerrado no escopo de backend transacional persistente, com migration `0033/0033` e 96/96 asserções.
- Inspeção confirmou que `apps/platform/src` ainda não chama as sete RPCs persistentes da `0033`.
- O aceite visual persistente não foi presumido nem descartado; foi transferido para uma trilha própria.
- Próximo módulo: M18 — integração visual persistente e UAT sintético.
- Piloto M15 real e produção continuam bloqueados até o parecer M18-G8.
- Marcador: `M17_G12_BACKEND_PERSISTENT_TRACK_CLOSED_M18_DEFINED`.
- Nenhum serviço remoto acessado e nenhum dado criado neste gate.
## M18-G0 — contrato da integração visual persistente (31/08/2026)

- Contrato `M18-VISUAL-1.0` mapeia seis superfícies visuais, sete RPCs e onze read models.
- Estados UX obrigam validação, submissão única, releitura e somente então sucesso.
- Dez ameaças cobrem tenant vindo do navegador, adulteração de valores, replay, aba obsoleta, erro SQL, segredo e estado otimista.
- 30/30 testes do contrato e 32/32 testes da plataforma, TypeScript e ESLint aprovados.
- Marcador: `M18_G0_VISUAL_PERSISTENCE_CONTRACT_OK`.
- Nenhum serviço remoto acessado e nenhum dado criado.
## M18-G1 — cliente server-side tipado (31/08/2026)

- Broker tipado cobre sete RPCs e onze read models com transporte injetável.
- Tenant, request ID e hash são derivados/validados no servidor; payload do navegador não recebe autoridade.
- Sucesso exige releitura persistente; falhas são sanitizadas e escrita não tem retry automático cego.
- 48/48 testes do pacote e 32/32 testes da plataforma, declarações TypeScript e ESLint aprovados.
- Marcador: `M18_G1_TYPED_SERVER_CLIENT_OK`.
- Nenhum serviço remoto acessado; conexão às telas começa no M18-G2.
## M18-G2 — cadastro e catálogo na fronteira visual local (31/08/2026)

- Telas `/cadastros` e `/catalogo` executam `party.create` e `catalog.item.create` pelo cliente server-side M18.
- Transporte local mantém snapshots sintéticos de clientes e produtos somente durante a sessão.
- Tenant não chega ao navegador; escrita Supabase direta foi removida dessas duas ações.
- 40/40 testes da plataforma, 49/49 do contrato, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G2_MASTER_DATA_VISUAL_LOCAL_OK`.
- Nenhum serviço remoto acessado e nenhum dado real criado.
## M18-G3 — estoque, caixa e PDV na fronteira visual local (31/08/2026)

- `/operacoes` usa `inventory.receive`; `/pdv` usa `cash.open` e `sale.complete` pelo broker M18.
- Preço é derivado no servidor; venda em dinheiro baixa estoque e atualiza esperado de caixa atomicamente no dublê.
- Estoque insuficiente, caixa ausente, dupla abertura e crediário falham fechado.
- 52/52 testes da plataforma, 49/49 do contrato, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G3_INVENTORY_CASH_POS_VISUAL_LOCAL_OK`.
- Nenhum serviço remoto acessado e nenhum dado real criado.
## M18-G4 — financeiro, fechamento e dashboard por releitura local (31/08/2026)

- Crediário exige cliente, gera recebível e permite baixa controlada por `financial.settle`.
- Fechamento usa `cash.close` e bloqueia divergência entre contado e esperado.
- Dashboard relê vendas, estoque, caixa e financeiro e reconcilia `vendas = dinheiro + crediário`.
- 62/62 testes da plataforma, 49/49 do contrato, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G4_FINANCE_CASH_DASHBOARD_LOCAL_OK`.
- Nenhum serviço remoto acessado e nenhum dado real criado.
## M18-G5 — auditoria local independente da jornada visual (31/08/2026)

- Tenant de escrita, replay e identidade do caixa foram auditados e remediados no transporte local.
- Receipts por request ID, RPC e hash tornam replay idêntico seguro e conflito fail-closed.
- Guardas de estoque, recebível, cliente e caixa precedem todas as mutações críticas.
- 12 controles independentes; 74/74 testes da plataforma, 49/49 do contrato, TypeScript, ESLint e build aprovados.
- Achados críticos/altos residuais no escopo local: zero.
- Marcador: `M18_G5_LOCAL_INDEPENDENT_AUDIT_OK`.
- Nenhum serviço remoto acessado e nenhum dado real criado.
## M18-G6 — adaptador PostgreSQL/Supabase local (31/08/2026)

- Pacote de transporte criado com allowlist das sete RPCs persistentes da `0033`.
- Nove planos de leitura aplicam seleção explícita, limites e `tenant_id` antes dos filtros funcionais.
- Saldo de estoque é derivado de `erp_stock_movement_items`; nenhuma view inexistente foi presumida.
- Agregados permanecem fail-closed até receberem implementação server-side injetada.
- 17/17 testes do adaptador, 49/49 do contrato, 74/74 da plataforma e build aprovados.
- Marcador: `M18_G6_SUPABASE_ADAPTER_LOCAL_OK`.
- Nenhuma tela conectada, nenhum serviço remoto acessado e nenhum dado criado.
## M18-G7 — agregados e composição persistente server-side (31/08/2026)

- Agregados tenant-scoped de financeiro e dashboard foram implementados com fontes explícitas.
- Janela de 5.000 registros falha fechado para impedir totais parciais ou truncados.
- Fábrica server-side compõe broker, adaptador, agregador e resolvedor de tenant por injeção.
- As telas continuam no transporte sintético; ativação remota permanece bloqueada.
- 23/23 testes do adaptador, 80/80 da plataforma, 49/49 do contrato, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G7_PERSISTENT_COMPOSITION_LOCAL_OK`.
- Nenhum serviço remoto acessado e nenhum dado criado.
## M18-G8 — auditoria final local e preflight read-only (01/09/2026)

- UUID de tenant foi endurecido e read models receberam chaves canônicas estáveis.
- Preflight SQL usa transação somente leitura, valida RPCs/relações/colunas/RLS/privilégios e termina em `ROLLBACK`.
- Formatos persistentes ainda precisam de normalização antes de conectar as telas; ativação visual permanece bloqueada.
- 31/31 testes do adaptador, 50/50 do contrato, 80/80 da plataforma, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G8_LOCAL_AUDIT_READ_ONLY_PREFLIGHT_READY`.
- Supabase remoto não acessado e nenhum dado criado.
## M18-G9 — preflight remoto somente leitura (01/09/2026)

- Branch `staging` e project ref `ozvylnaipubrmaadikvk` confirmados antes da conexão.
- Preflight SHA-256 `B834D673A87B5BB41E54CFA046FF2D1E53A5240E2050788CE89DD071344A6A55` executado com sucesso.
- Marcador remoto obrigatório: `M18_G8_READ_ONLY_PREFLIGHT_OK`.
- Transação somente leitura encerrada com `ROLLBACK`; nenhuma RPC de comando ou migration executada.
- Marcador: `M18_G9_REMOTE_READ_ONLY_PREFLIGHT_OK`.
- Nenhuma conta, fixture, receipt ou dado criado; produção não acessada.

## M18-G10 — normalização local dos read models persistentes (01/09/2026)

- Read models persistentes foram convertidos para os formatos canônicos consumidos pelas telas.
- Isolamento por tenant, números inválidos, liquidação excessiva e modelos desconhecidos falham fechado.
- Dashboard persistente foi alinhado ao formato visual e reconcilia vendas, caixa e recebíveis confirmados.
- 44/44 testes do adaptador, 50/50 do contrato, 80/80 da plataforma, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G10_PERSISTENT_READ_MODELS_NORMALIZED_LOCAL_OK`.
- Nenhum novo acesso remoto; telas continuam no transporte sintético e produção permanece bloqueada.

## M18-G11 — seleção fail-closed do transporte visual (01/09/2026)

- Fachada server-side única passou a atender dashboard, cadastros, catálogo, estoque, PDV, caixa e financeiro.
- Somente o dublê sintético local é selecionado; modo persistente falha antes de tocar qualquer dependência.
- Modo inválido, ausente ou sem dublê também é recusado de forma determinística.
- 86/86 testes da plataforma, 50/50 do contrato, 44/44 do adaptador, TypeScript, ESLint e build aprovados.
- Marcador: `M18_G11_FAIL_CLOSED_VISUAL_TRANSPORT_LOCAL_OK`.
- Nenhum serviço remoto acessado; Supabase, Vercel e produção permanecem bloqueados.

## M18-G12 — persistência visual somente leitura em staging (01/09/2026)

- Flag privada aceita apenas `synthetic` e `persistent-read-only`; escrita e valores desconhecidos falham fechado.
- Leituras persistentes exigem sessão e tenant derivados no servidor; comandos são bloqueados antes da conexão.
- Preflight remoto retornou `M18_G12_PERSISTENT_READ_ONLY_OK` em transação somente leitura com `ROLLBACK`.
- Sete RPCs presentes, RLS ativa, tenant sintético ausente e zero command receipts confirmados.
- 93/93 testes da plataforma, 50/50 do contrato, 44/44 do adaptador, TypeScript, ESLint e build aprovados.
- Nenhuma RPC, migration ou escrita executada; produção não acessada.

## M18-G13 — provisionamento protegido do piloto em dry-run (01/09/2026)

- Plano determinístico de 13 ações preparado para `maniademodas`, sem executor de escrita.
- CNPJ, IE, razão social e e-mail são aceitos somente por referências protegidas; valores diretos e segredos falham fechado.
- Usuário-piloto exige convite, papel `owner`, MFA e AAL2; `--apply`, rede e produção permanecem bloqueados.
- Preflight remoto somente leitura retornou `M18_G13_PILOT_PREFLIGHT_OK` e encerrou com `ROLLBACK`.
- 14/14 testes M18-G13, 107/107 da plataforma, 50/50 do contrato, 44/44 do adaptador, TypeScript, ESLint e build aprovados.
- Nenhum tenant, usuário, estabelecimento, membership, papel, fixture ou dado real criado; produção não acessada.

## M18-G14 — executor transacional local do piloto (01/09/2026)

- Unidade de trabalho local implementada com rollback integral em seis pontos de falha.
- Replay idêntico é idempotente; tenant divergente, referência ausente e modo remoto falham fechado.
- Convite de identidade permanece em outbox pendente e não executável; MFA/AAL2 e owner integram o contrato.
- Identidades protegidas não são resolvidas ou persistidas; somente referências e fingerprints são usados.
- 27/27 testes focados, 120/120 da plataforma, TypeScript, ESLint e build aprovados.
- Supabase, Auth, Vercel e produção não foram acessados; nenhum dado foi criado.

## M18-G15 — auditoria do mapeamento PostgreSQL/Auth (01/09/2026)

- Dez alvos persistentes e onze passos da ordem segura foram mapeados.
- Tenant é resolvido por membership; profile Auth não recebe autoridade por metadata ou JWT.
- Banco deve confirmar tenant/outbox antes do convite Auth; vínculo final ocorre em nova transação e exige AAL2.
- Seis bloqueios impedem criação efetiva: RPC atômica, allowlist do ledger, outbox, fronteira Auth/banco, IE e compensação.
- Marcador `M18_G15_MAPPING_AUDIT_OK`; 7/7 testes focados, 127/127 da plataforma, TypeScript, ESLint e build aprovados.
- Nenhum serviço remoto acessado e nenhum dado criado; aplicação permanece bloqueada.

## M18-G16 — migration local 0034 (01/09/2026)

- Inscrição estadual, domínio único, outbox Auth e compensação durável implementados localmente.
- Quatro RPCs server-only cobrem preparação atômica, registro Auth, finalização e compensação.
- Preflight read-only, rollback vazio protegido e 72 asserções pgTAP foram preparados.
- SHA-256 original: `DDCF72B5B39D8BD407ECB7B928F547DFDF097F254329BAA0711CC1FC4279C715`; substituído no M18-G17 após remediação.
- 15/15 testes estáticos, 142/142 da plataforma, 50/50 do contrato, 44/44 do adaptador e build aprovados.
- Docker local não disponibilizou o engine; PostgreSQL/pgTAP permanecem pendentes. Remoto e produção não foram acessados.

## M18-G17 — auditoria e validação PostgreSQL local da 0034 (01/09/2026)

- Banco local reconstruído integralmente pelas migrations `0001–0034`.
- Auditoria adversarial encontrou e corrigiu quantidade desigual de valores e `step_key` fora do contrato.
- 72/72 asserções estruturais e 18/18 adversariais aprovadas em transações com `ROLLBACK`.
- Replay idempotente, segredo, campo desconhecido, caller autenticado, MFA, capacidades e outbox foram exercitados.
- Hash final da `0034`: `0551FD5EF16B2BCD3F530EBED65FE1CBFAB0EA3D651899F6EBD5167610F48251`.
- Zero tenant sintético, outbox ou compensação residual; remoto e produção não acessados.

## M18-G18 — validação transacional remota da 0034 (01/09/2026)

- Dry-run remoto selecionou exclusivamente a migration `0034`.
- Preflight retornou `M18_0034_PREFLIGHT_OK` antes e depois da validação.
- Pacote exato passou localmente e remotamente com 90/90 asserções.
- Marcador remoto: `M18_0034_TRANSACTION_90_OF_90_ROLLBACK`.
- Histórico remoto permanece em `0033`; a `0034` não foi aplicada persistentemente.
- Nenhum tenant, usuário, identidade ou dado persistiu; produção não acessada.

## M18-G19 — aplicação persistente da 0034 no staging (01/09/2026)

- Preflight aprovado e somente a migration `0034` foi aplicada persistentemente.
- 72/72 asserções estruturais e 18/18 adversariais foram repetidas com sucesso.
- Marcador final: `M18_G19_0034_APPLIED_90_OF_90_ZERO_DATA`.
- Histórico remoto `0034/0034`; dry-run final sem migrations pendentes.
- Zero tenant, identidade, membership, outbox, compensação ou run M18 criado.
- Produção não acessada; criação da empresa-piloto permanece em portão separado.

## M18-G20 — coleta protegida e preflight final (01/09/2026)

- Coletor mascarado e validador fail-closed implementados com cofre DPAPI fora do projeto e Git.
- Quatro campos obrigatórios validados somente em memória: razão social, CNPJ, IE e e-mail do owner.
- 8/8 testes focados, testes da plataforma, TypeScript, ESLint e build aprovados com Node.js 22.
- Preflight remoto somente leitura aprovado: `M18_G20_REMOTE_PREFLIGHT_OK`.
- Zero gravações no Supabase e produção não acessada.
- Coleta local concluída e cofre validado: `M18_G20_PROTECTED_CONFIG_OK`; nenhum valor foi registrado em Git ou logs.
- Estado: aprovado; provisionamento efetivo permanece bloqueado em portão separado.
- Coletor remediado após falha de autoload do módulo PowerShell.Security; DPAPI direto, parser, ASCII e 8/8 testes aprovados.
- Assembly `System.Security` carregado explicitamente e ida e volta DPAPI comprovada no Windows PowerShell 5.1: `WINDOWS_POWERSHELL_51_DPAPI_OK`.

## M18-G21 — provisionamento do piloto no staging (01/09/2026)

- Preflights PostgreSQL e Auth aprovados; e-mail do piloto estava ausente.
- Tenant Mania de Modas, estabelecimento, usuário Auth, membership owner e convite foram criados no staging.
- Run de provisionamento `completed`, outbox `sent`, MFA/AAL2 obrigatório e zero compensações.
- Executor fail-closed aprovado com 11/11 testes; testes da plataforma, TypeScript, ESLint e build aprovados.
- Valores protegidos e chave service role permaneceram somente em memória; produção não acessada.
- Estado: `M18-G21 APROVADO`.

## Documentação — CLAUDE.md e AGENTS.md (02/09/2026)

- `CLAUDE.md`/`AGENTS.md` reescritos com a arquitetura real do repositório para orientar
  agentes de IA: identidade do clone (`staging`, sem `docs/`), governança de execução
  automática, comandos por app/pacote (sem workspace raiz, pin Node 22), os três apps Next.js
  e seus modelos de acesso, o padrão de módulo de `apps/platform/src/features`, os pacotes de
  contrato em `packages/*` e a governança de migrations do Supabase (preflight/tests/rollback/
  verification/validation).
- Regra ADHD-Friendly Output preservada integralmente no topo de ambos os arquivos.
- `AGENTS.md` sincronizado como cópia idêntica de `CLAUDE.md`.
- Commit `be30281` na branch `staging`, publicado em `origin/staging`
  (`dcf647b..be30281`).
- Nenhum código de aplicação, schema, migration ou dado alterado; apenas documentação.
- Estado: aprovado.

## Correção — CI "Quality gates" desbloqueado (02/09/2026)

- Diagnóstico: `gh run list` mostrou todo run da branch `staging` como `failure` desde
  30/08/2026 (inclusive os dois pushes de documentação anteriores), sem relação com o
  conteúdo de cada commit — falha estrutural pré-existente, não causada por este trabalho.
- Causa 1 (`apps/platform`, job `platform`, etapa `npm run build`): cinco rotas
  (`/alimentacao`, `/atendimento`, `/bancos`, `/servicos`, `/vendas`) não declaravam
  `export const dynamic='force-dynamic'` — diferente de todas as demais rotas de
  `(painel)`. O Next.js tentava pré-renderizar em build time, batendo em
  `Error: Supabase não configurado` no runner do GitHub Actions (sem
  `NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`). Corrigido adicionando
  a mesma diretiva usada nas demais rotas.
- Causa 2 (`packages/fiscal-contract`, job `critical-contracts (fiscal-contract)`, teste
  `hash oficial confere`): `nfe_v4.00.xsd` e `xmldsig-core-schema_v1.01.xsd` sofreram drift
  de line-ending (CRLF local via `core.autocrlf=true` de quem commitou, divergindo do LF
  gravado no blob do Git) — hash SHA-256 deixava de bater com `schema-manifest.json`.
  Bytes restaurados a partir do `PL_010e_v1.02.zip` oficial já versionado (hash do ZIP
  sempre conferiu); `.gitattributes` criado marcando `packages/fiscal-contract/schemas/**`
  como `-text` para impedir recorrência em qualquer máquina.
- Evidência local antes do commit: `platform` 161/161 testes + build limpo sem variáveis de
  ambiente (reproduz o runner); `fiscal-contract` 234/234; type-check e lint limpos.
- Evidência remota: commit `bba6f34` — run `33714605809` do "Quality gates" concluído
  `success` nos 8 jobs (`platform`, `portal`, `site`, `security-static`,
  `critical-contracts` × fiscal-contract/device-protocol/import-contract/pilot-journey).
- Nenhuma migration, schema de banco ou dado alterado; escopo é código de aplicação e
  arquivo de schema oficial restaurado ao original. Estado: aprovado.

## Validação — apps/portal e apps/site local (02/09/2026)

- Confirmação local dos três apps após o fix de CI, fechando a paridade com os 8/8 jobs
  remotos do run `33714605809`.
- `apps/portal`: 56/56 testes, `type-check` limpo, `lint` limpo, `build` limpo (8/8 rotas).
- `apps/site`: 5/5 testes, `lint` limpo, `build` limpo (14/14 rotas). Primeiro `type-check`
  acusou erro em `.next/types/routes.d.ts` — arquivo gerado, não código-fonte; causado por
  cache `.next` local desatualizado. Limpo e reexecutado: sem erro.
- Nenhum arquivo de código alterado nesta validação — só confirmação de estado.

## M19-G0 — escopo do redesign visual + roteamento de login (02/09/2026)

Registrado antes de implementar, por decisão do usuário sobre `/tenants` (achado: menu
lateral de `apps/platform` sem hierarquia, 19 links soltos) e pedido explícito de evoluir pra
um programa maior. Autorização: "Fazer tudo nesta ordem cronologica sem minha intervenção".

- **Fase 1 — Tema global + dark mode**: paleta oficial (8 tons) consistente nos 3 apps;
  alternador manual claro/escuro persistido em `localStorage`, sem tocar sessão/tenant.
- **Fase 2 — Redesign do painel** (`apps/platform`): aplicar o padrão visual de
  `apps/portal` `/demo` (topbar com identidade + usuário, cards de KPI, ações rápidas) nas
  telas do painel interno.
- **Fase 3 — Branding por tenant**: migration nova + engrenagem de configuração no portal de
  cada empresa, permitindo cor primária e ícone próprios sobrepondo a paleta global só ali.
- **Fase 4 — Roteamento de login por papel**: form único no site identifica o e-mail e
  redireciona (sem sessão compartilhada entre domínios — cookie do portal é host-only, decisão
  de segurança já documentada em M03): `admin@connectioncyber.com.br`-like (staff) →
  `apps/platform`; aluno/academy → `apps/site` `/membros`; e-mail de empresa cliente → portal
  da própria empresa (`<slug>.connectioncyber.com.br`), autenticação real acontece lá.

Critério de aceite por fase: testes + type-check + lint + build limpos nos apps tocados;
nenhuma migration remota aplicada fora do portão específico da Fase 3; nenhuma credencial ou
sessão cruzando domínio sem autenticação própria no destino.

## M19-G1 — tema global e dark mode (02/09/2026)

- Paleta oficial (8 tons) confirmada consistente: `apps/platform`/`apps/site` já a tinham via
  `theme.css` compartilhado; `apps/portal` tinha só as 4 tonalidades base — as 4 "alt"
  (`#F8961D`, `#CA2127`, `#4CB853`, `#28A992`) foram adicionadas sem renomear tokens existentes
  (baixo risco de regressão nos ~50 usos já espalhados pelo portal).
- Dark mode: os 3 apps já respeitavam `prefers-color-scheme` nos tokens semânticos
  (`--cc-bg`/`--cc-text`/... em platform/site; `--ink`/`--surface`/... em portal, este último
  sem suporte algum antes). Adicionado alternador manual — classes `.dark`/`.light` em `<html>`
  com especificidade maior que o media query, sempre vencendo a preferência do sistema nos dois
  sentidos.
- `ThemeToggle` (um componente por app, sem pacote compartilhado — mesmo padrão já usado entre
  `apps/site`/`apps/platform` pra `theme.css`) só lê/grava `localStorage['cc-theme']; nenhuma
  chamada a Supabase, sessão ou tenant.
- Script inline bloqueante no `<head>` de cada app (`app/layout.tsx` em platform/portal,
  `_document.tsx` em site) aplica a classe salva antes da primeira pintura — sem flash
  claro→escuro.
- Testes novos por app confirmam o mecanismo (script presente, toggle sem I/O de sessão,
  especificidade do CSS); suítes completas: `platform` 165/165, `portal` 60/60, `site` 9/9;
  type-check, lint e build limpos nos 3.
- Nenhuma migration, dado remoto ou sessão alterada — mudança é só client-side/CSS.

## M19-G2 — redesign do painel (02/09/2026)

Escopo real desta gate: **shell compartilhado** (topbar, sidebar, sistema de cards/grid) e a
**home do dashboard**, no padrão visual de `apps/portal` `/demo` (cards de KPI limpos,
saudação, menos borda pesada). Como as ~19 telas de módulo reusam essas mesmas classes CSS
(`pf-content-card`, `pf-button`, `pf-page-header`...), o visual novo já propaga pra todas —
redesenho bespoke do conteúdo interno de cada tela individual **não** foi feito nesta gate
(ficaria em portões futuros se o padrão atual não for suficiente).

- `.pf-content-card`: borda de 1.5px laranja em volta de tudo (decisão de 2026-08-15) trocada
  por borda neutra de 1px + sombra — menos ruído com o menu já agrupado em seções (M19-G1).
- `.pf-sidebar-link`: caixa com borda em cada um dos ~20 itens virou link plano; item ativo
  ganha barra lateral laranja de 3px em vez da caixa inteira colorida.
- Novo `.pf-stat-card`/`.pf-grid-3`: cards de KPI com número em destaque e tira laranja só no
  topo. `.pf-grid-3` **não existia** em CSS antes — a home referenciava a classe no
  `page.tsx` sem ela estar definida; os 6 cards caíam empilhados, sem grade nenhuma. Corrigido.
- Topbar ganhou avatar circular (inicial do e-mail) ao lado do texto de sessão.
- Dashboard (`(painel)/page.tsx`) ganhou saudação amigável. Tentativa inicial de personalizar
  com o nome do usuário violava a regra do M18-G11 (telas de módulo não podem importar Supabase
  direto — só o seletor fail-closed `features/persistence/selected` pode); corrigido para
  saudação genérica, sem tocar Supabase nesta tela.
- Todos os tokens de cor já vêm de `--cc-*` (herdados do M19-G1), então dark mode funciona
  automaticamente no shell novo sem CSS adicional.
- `platform` 165/165 (mais o teste que capturou a violação do M18-G11 antes do commit),
  type-check, lint e build limpos.
- Nenhuma migration, dado remoto ou sessão alterada — mudança é CSS/TSX client+server local.

## M19-G3 — branding por tenant, migration aplicada em staging (02/09/2026)

- Nova tabela `public.erp_tenant_branding` (tenant_id PK, `primary_color`/`logo_url`
  opcionais, formato validado por `check`), RLS (`select`: membro do tenant ou equipe;
  `insert`/`update`: permissão `branding.manage` ou equipe) e RPC
  `public.erp_set_tenant_branding` — `security invoker`, RLS na tabela é a fronteira real
  (mesmo padrão de `erp_create_party`/0021, não o broker `service_role`-only usado em
  operações só de equipe).
- Permissão `branding.manage` inserida no catálogo e retroaplicada (`erp_role_permissions`)
  aos papéis `owner`/`admin` dos tenants já provisionados (ConnectionCyber, Mania de Modas);
  provisionamento futuro já herda automaticamente via `erp_finalize_pilot_identity_v1` (0034).
- 16 testes pgTAP (positivo + negativo): escrita cross-tenant bloqueada pela RLS, escrita sem
  `branding.manage` bloqueada, cor/URL fora do formato recusadas pela função, leitura isolada
  por tenant, `updated_by` reflete a sessão real.
- Suíte local completa (20 arquivos, `0001`–`0035`) rodada no Postgres local via Docker:
  zero falhas, zero regressão.
- Preflight remoto: `M19_0035_PREFLIGHT_OK`. Dry-run transacional remoto (migration + 16
  testes reais dentro de uma transação terminada em `ROLLBACK`, mesmo mecanismo de
  `build-0033-transaction.mjs`): `M19_0035_TRANSACTION_16_OF_16_ROLLBACK`, zero resíduo
  confirmado (tabela e permissão ausentes após o rollback).
- **Aplicação persistente confirmada** via `npx supabase db push --linked` (autorizado pelo
  usuário) — histórico remoto `0001–0035` alinhado. UI que consome esta migration (engrenagem
  de configuração no portal) é a Fase 3 restante, ainda não implementada.
- Produção não acessada; nenhum dado de cliente criado.

## M19-G4 — engrenagem de identidade visual no portal (03/09/2026)

- Nova tela `apps/portal` `/configuracoes/aparencia`: dono/admin do tenant define cor
  principal (`<input type="color">`, zero JS) e logo (`<input type="url">`), no mesmo idioma
  100% servidor + formulário sem JS já usado em todo o app (`select-membership`/`route.ts`
  como referência) — nenhum client Supabase novo introduzido.
- Escrita real passa só pela RPC `erp_set_tenant_branding` (migration `0035`); o novo route
  handler (`auth/set-branding/route.ts`) revalida formato no servidor mesmo já validado no
  browser, resolve o tenant sempre da sessão (nunca de input do formulário), e devolve erro
  genérico sem distinguir "sem permissão" de "formato recusado".
  `apps/portal/src/lib/branding.ts` recalcula a mesma checagem de permissão da RLS só pra
  decidir se a engrenagem *aparece* — a fronteira de segurança continua sendo a RLS/RPC no
  banco, independente do que essa função conclui (falso positivo aqui só mostraria um botão
  que a RPC recusaria em seguida, nunca uma falha real).
- Leitura de branding (`loadTenantBranding`) falha aberto pro padrão global em qualquer erro —
  é dado cosmético, nunca pode derrubar a renderização do portal.
- `Brand.tsx` aceita `logoUrl` opcional; cor do tenant sobrepõe só `--orange`/`--orange-alt`
  via `<style>` injetado no layout (revalidado no servidor antes de renderizar) — `--orange-soft`
  fica no tom global, calcular tint de hex arbitrário ficou fora de escopo.
- Fora de escopo (documentado, não implementado): upload de logo via Supabase Storage — a
  `0035` só suporta URL `https://`.
- `apps/portal`: 75/75 testes (16 novos: 7 de validação pura de cor/URL, 9 de asserção textual
  garantindo same-origin check, revalidação server-side, RPC como único caminho de escrita e
  ausência de `service_role` em toda a feature), type-check, lint e build limpos.
- Nenhuma migration nova; nenhum dado remoto alterado além do que o próprio usuário salvar
  pela tela (ninguém salvou nada ainda — feature nova, staging sem uso real até aqui).

## Incidente e correção — convite redirecionava pra localhost, token vazou (04/09/2026)

- **Achado de segurança real**: ao clicar no convite corrigido, o Supabase Auth redirecionou
  o navegador pra `http://localhost:3000/#access_token=...` (não pra nenhum host real) — um
  `access_token`/`refresh_token` válidos da conta do dono ficaram expostos na URL, capturados
  em print e colados em texto solto. **Ação imediata**: sessão revogada globalmente
  (`POST /auth/v1/logout?scope=global` usando o próprio token vazado contra si mesmo, único
  uso dele depois de exposto) — `204`, confirmado.
- **Causa raiz**: o `site_url` do projeto Supabase de staging nunca tinha sido configurado —
  ficou no padrão de desenvolvimento (`http://localhost:3000`) desde sempre. O convite original
  (M18-G20/G21) não passou `redirect_to` explícito, então o Auth usou esse padrão. Segundo
  problema: `apps/portal` nunca teve rota nenhuma pra receber esse token — Supabase Auth entrega
  o token no **fragmento** da URL (`#access_token=...`), que nunca chega ao servidor (Server
  Component/Route Handler não veem `location.hash`), então processar isso é obrigatoriamente
  client-side. O app inteiro até aqui era 100% formulário sem JS.
- **Terceiro problema, mais profundo**: mesmo com login funcionando perfeitamente, nada no
  sistema jamais fazia `erp_tenant_memberships.status` sair de `'invited'` pra `'active'` —
  `decidePortalAccess`/`isMembershipActive` exige `status='active'`; sem essa transição, a
  pessoa teria sessão válida e ainda assim receberia `forbidden` pra sempre.
- **Correção** (código): `apps/portal/src/lib/supabase/client.ts` (primeiro client Supabase no
  browser deste app — só serve pra isto), `apps/portal/src/app/auth/confirm/page.tsx` (lê o
  fragmento, chama `setSession`, limpa a URL do histórico, guia a pessoa a definir senha, chama
  a RPC nova pra ativar a membership). Migration `0036_m18_accept_membership_invite.sql` — RPC
  `erp_accept_pending_memberships_v1()` (`security definer`, sempre escopada a `auth.uid()`,
  não recebe parâmetro — não há como ativar membership de outro usuário). 7 testes pgTAP
  (positivo/negativo/isolamento entre usuários/idempotência), suíte local completa 22/22
  arquivos sem regressão, preflight e dry-run remoto (`M18_0036_TRANSACTION_7_OF_7_ROLLBACK`)
  antes da aplicação persistente. `apps/portal` 80/80 testes, type-check, lint, build limpos.
- **Correção** (config): `supabase/config.toml` `[auth]` `site_url` →
  `https://portal.connectioncyber.com.br`; `additional_redirect_urls` cobrindo
  `portal.connectioncyber.com.br`, `maniademoda.connectioncyber.com.br` e o curinga
  `*.connectioncyber.com.br`, todos em `/auth/confirm`.
- **Quase-incidente na aplicação da config**: `supabase config push` não aplica só o campo
  pedido — sincroniza o `[auth]` inteiro do `config.toml` contra o remoto. O arquivo local tinha
  valores obsoletos nunca antes sincronizados (`mfa.totp.enroll_enabled`/`verify_enabled` em
  `false`, `email.enable_confirmations` em `false`, OTP mais curto/frequente) que **foram
  aplicados de verdade no primeiro push**, desligando cadastro de MFA e confirmação de e-mail
  no staging por um período — descoberto no diff do push seguinte (mostrou o remoto ainda com
  os valores antigos "corretos" sendo substituídos pelos novos "errados" outra vez, provando que
  o primeiro push persistiu). Corrigido revertendo esses campos no `config.toml` pros valores
  reais (`true`/`true`/`true`/OTP restaurado) e reaplicando — confirmado `up_to_date` em todos
  os serviços depois, e `mailer_autoconfirm:false` confirmado ao vivo via
  `/auth/v1/settings`. **Lição registrada**: `config push` nunca deve ser usado pra mudar um
  campo isolado sem primeiro conferir que o resto do arquivo local reflete o estado real
  pretendido do remoto — não é uma operação cirúrgica.
- Nenhuma migration remota faltou verificação; incidente do Management API do Supabase
  (`PARECER-INCIDENTES-SUPABASE-STATUS.md`) não impediu nenhuma das operações desta gate.

## Correção — e-mail errado do dono-piloto substituído (04/09/2026)

- O e-mail coletado na coleta protegida original (M18-G20/G21) estava digitado errado — a
  pessoa certa nunca recebeu o convite; o e-mail confirmado em 02/09 pertencia a uma caixa
  errada, nunca usada pra entrar (login/MFA zero desde a criação).
- Correção pelo mesmo mecanismo de coleta protegida: `Collect-PilotProvisioningProtected.ps1`
  rodado de novo pelo usuário com o e-mail correto (nunca digitado em chat), seguido de novo
  script `apps/platform/scripts/Fix-PilotOwnerEmail.ps1` (`-PreflightOnly` depois `-Apply`).
- Convite novo enviado ao e-mail correto; membership+papel `owner` novos criados via
  PostgREST com `service_role` (ignora RLS por padrão, sem precisar de RPC nova só pra isto).
- **Achado real do schema, não bug**: a tentativa de apagar o usuário antigo foi recusada pela
  Auth API (`23503`, FK violation) — `erp_identity_provisioning_steps` referencia esse
  `user_id` sem cascata, de propósito, porque é histórico real de auditoria do provisionamento
  original. Comportamento correto: preservar auditoria em vez de permitir apagar. Fallback
  seguro aplicado — usuário antigo mantido inerte, membership dele marcada `revoked` (não
  apagada). Script atualizado para fazer esse fallback automaticamente da próxima vez.
- Estado final: exatamente uma membership `owner` viva (e-mail correto, `invited`, aguardando
  aceite) por tenant; a antiga preservada como `revoked` para rastreabilidade.
- Nenhum dado de auditoria apagado; produção não acessada.

## Portão 0 — publicação do apps/portal e ativação do domínio da Mania de Modas (04/09/2026)

- `apps/portal` publicado pela primeira vez (projeto Vercel `connectioncyber-portal`, staging
  como backend — ver commit `ba47173`), com dois bugs reais corrigidos no processo (Framework
  Preset nulo, variável de ambiente corrompida por um erro de pipe na CLI).
- **Conflito real encontrado e resolvido**: a Hostinger já tinha um subdomínio próprio
  (`Sites da Web → Subdomínios`) e um registro DNS específico para `maniademoda`, apontando
  pra hospedagem própria da Hostinger — tinha prioridade sobre o CNAME curinga
  (`*.connectioncyber.com.br → cname.vercel-dns.com`) por regra de DNS (registro específico
  sempre vence curinga, mesmo de tipo diferente). Removido pelo usuário na Zona DNS.
- Confirmado em 3 fontes independentes, sem cache, que o DNS corrigido propagou: nameserver
  autoritativo, resolvedor público (8.8.8.8) e resolvedor nativo do Windows.
- SSL emitido pela Vercel após registrar `maniademoda.connectioncyber.com.br` explicitamente
  como domínio do projeto (o curinga sozinho não disparou a emissão em ~20 min).
- **Última peça**: linha em `public.erp_tenant_domains` pro tenant Mania de Modas nunca tinha
  sido gravada (tenant/membership/convite existiam desde M18-G21, mas nenhum domínio). Sem
  ela, DNS+SSL certos ainda devolviam 404 de propósito (`classifyPortalHostname` correto,
  `portal_resolve_host` sem linha pra casar). Inserida via `supabase db query --linked`
  (escrita de dado, não ação de ciclo de vida — Management API em Major Outage no momento não
  bloqueou, conforme `PARECER-INCIDENTES-SUPABASE-STATUS.md`).
- **Confirmado**: `https://maniademoda.connectioncyber.com.br/login` responde 200, mostra
  "Entrar em Mania de Modas", SSL válido. Portão 0 do manual de ativação concluído por completo.
- Próximo: M18-G22 (dono aceita o convite + MFA) agora tem, pela primeira vez, um endereço real
  pra abrir — antes disso era literalmente impossível, mesmo com o convite na caixa de entrada.

## M19-G5 — roteamento de login por papel, sem lookup de e-mail (03/09/2026)

- `apps/site` `/login` virou seletor de 3 caminhos, mantendo o form de aluno original como um
  deles (só trocando o redirect cru da query string pelo novo `safeSiteRedirect`, fechando um
  gap de open-redirect que já existia): **aluno/academy** (autentica ali mesmo, inalterado
  além do fix), **equipe ConnectionCyber** (endereço do `platform.connectioncyber.com.br` como
  texto simples, **não** link clicável — decisão confirmada com o usuário, preserva a postura
  documentada de "sem link público" do painel interno), **empresa com portal próprio** (campo
  de slug/hostname, navega pro portal da empresa onde a autenticação real acontece).
- **Desenho rejeitado, registrado por completude**: um endpoint público resolvendo "a qual
  tenant esse e-mail pertence" antes de qualquer login. Seria um oráculo novo de enumeração de
  conta e o primeiro uso de `service_role` pré-autenticação em `apps/site` fora de webhook de
  pagamento — sem reduzir esforço real de quem já sabe se é aluno/equipe/empresa. **Nenhuma
  migration nova nem endpoint novo foi criado** para este gate.
- `buildCompanyPortalLoginUrl` é 100% client-side, zero chamada de rede — só monta a URL
  (slug vira `<slug>.connectioncyber.com.br`, ou aceita hostname completo já com ponto) e
  navega; a existência real do tenant continua resolvida só no destino
  (`classifyPortalHostname`+`portal_resolve_host` de `apps/portal`, sem mudança).
- `apps/site`: 19/19 testes (10 novos: 2 de `safeSiteRedirect`, 3 de `buildCompanyPortalLoginUrl`
  — funções puras, `assert.equal` de verdade — e 5 de asserção textual confirmando os 3
  caminhos presentes, card da equipe sem link clicável, caminho da empresa sem `fetch(`, e
  ausência de endpoint/`service_role` novo, travando contra volta silenciosa pro desenho
  rejeitado), type-check, lint e build limpos. `platform` 165/165 sem regressão (não foi
  tocado nesta gate).
- Fecha o M19 (Fases 1–4 completas: tema/dark mode, redesign do painel, branding por tenant,
  roteamento de login).

## Incidente e correção 2 — botão do Studio ignorava `/auth/confirm`, membership ativada (04/09/2026)

- **Segundo vazamento de token, mesma classe de falha**: convite corrigido reenviado (dono já
  confirmado por ter clicado no link vazado do incidente anterior — GoTrue recusa reenviar
  convite pra usuário já confirmado), então usado **magic link** via Supabase Studio em vez de
  API. O botão **"Send magic link" do Studio não aceita `redirect_to` customizado** — sempre usa
  o `site_url` puro do projeto. Como `site_url` apontava só pra raiz do domínio
  (`https://portal.connectioncyber.com.br`, sem `/auth/confirm`), o link caiu no dashboard raiz
  com o token no fragmento da URL; middleware não-autenticado redirecionou pra `/login`
  preservando o fragmento (o servidor nunca vê `#...`) — token exposto de novo, colado em texto
  solto de novo. **Ação imediata**: `POST /auth/v1/logout?scope=global` com o próprio token
  vazado — `204`, confirmado revogado.
- **Causa raiz real**: `site_url` era só a raiz do domínio, não a página que trata o hash. Ações
  disparadas pelo Studio (convite, magic link, recovery) nunca respeitam `redirect_to` — só as
  chamadas feitas via API com o parâmetro explícito respeitavam (é por isso que o convite
  original, corrigido via `Fix-PilotOwnerEmail.ps1` com `redirect_to` na chamada, funcionou até
  a validação; o clique via Studio, sem esse parâmetro, não).
- **Correção** (config, aplicada manualmente no Supabase Studio — `supabase config push` via
  CLI ficou bloqueado pelo classificador de permissão do Claude Code neste ambiente, mesmo após
  liberar `Bash` em `/permissions`; contornado com edição direta em
  Authentication → URL Configuration):
  - `site_url`: `https://portal.connectioncyber.com.br` →
    `https://portal.connectioncyber.com.br/auth/confirm` — agora qualquer ação do Studio sem
    `redirect_to` cai direto na página que sabe tratar o token, não mais na raiz.
  - `additional_redirect_urls` (chamado de "Redirect URLs" na UI do Studio): durante a correção
    manual, os 4 valores anteriores foram apagados por engano e só 1 recolocado
    (`portal.connectioncyber.com.br/auth/confirm`); restaurado adicionando o curinga
    `https://*.connectioncyber.com.br/auth/confirm` (cobre portal + `maniademoda` + qualquer
    tenant futuro numa entrada só). Ficou com 2 entradas no remoto — `config.toml` local
    ajustado pra bater exatamente com isso (removida a entrada exata de `maniademoda`, redundante
    com o curinga, e a de `127.0.0.1:3021`, sem uso de dev local com fluxo de e-mail até agora;
    comentário no arquivo registra como restaurar se precisar).
- **Teste real de ponta a ponta, confirmado por print**: novo magic link enviado → e-mail
  recebido → clique cai em `/auth/confirm` limpo (sem token visível na tela) → senha definida →
  redireciona pro dashboard real do portal (`portal.connectioncyber.com.br/dashboard`) com
  "Empresa ativa: Mania de Modas" e "Contexto validado".
- **Confirmado no banco**: `erp_tenant_memberships.status = 'active'` pro dono real (antiga
  membership com e-mail errado permanece `'revoked'`, histórico preservado). Piloto da Mania de
  Modas está com acesso real funcionando de ponta a ponta.
- **Pendência aberta**: `git`/`config.toml` e o remoto ficaram alinhados manualmente desta vez;
  se um `config push` futuro for tentado, conferir que o diff mostrado bate exatamente com essas
  2 entradas antes de confirmar — mesma lição do incidente anterior, reforçada.

## M18-G22 — tela de MFA/TOTP implementada; falta o piloto usar de verdade (04/09/2026)

- **Achado que motivou esta gate**: nenhum app tinha `supabase.auth.mfa` em lugar nenhum —
  `erp_roles.requires_mfa` (migration 0018, já `true` pro papel `owner` da Mania de Modas desde
  o provisionamento na 0034) nunca era checado por ninguém. Login funcionava, sessão ficava em
  `aal1` pra sempre, e não existia rota nenhuma em `apps/portal` onde a pessoa pudesse cadastrar
  um segundo fator — o requisito de MFA do dono estava só no schema, nunca aplicado na prática.
- **Implementado em `apps/portal`**:
  - `src/domain/mfa-gate.ts` — função pura `decideMfaGate` (papel exige aal2? sessão já está em
    aal2? já está na própria tela de segurança, pra não formar loop?) → `allow` ou
    `redirect-to-security`. Zero I/O, testada isolada.
  - `src/lib/mfa.ts` — `membershipRequiresAal2` (mesma leitura de `erp_membership_roles` →
    `erp_roles.requires_mfa` que `canManageBranding` já fazia pra branding, agora pra MFA) e
    `getCurrentAal` (`supabase.auth.mfa.getAuthenticatorAssuranceLevel()`). Os dois **fail-closed
    ao contrário de `canManageBranding`**: erro assume que aal2 É exigido e NÃO foi satisfeito —
    a direção mais restritiva, nunca a mais permissiva (trava com teste dedicado).
  - `(portal)/layout.tsx` — aplica o gate em toda rota autenticada (novo header
    `x-cc-pathname` propagado pelo middleware, mesmo mecanismo já usado pra `x-cc-portal-host`);
    redireciona pra `/configuracoes/seguranca` sem alterar nenhuma autorização real de dado —
    isso continua sendo só RLS/RPC no banco.
  - `/configuracoes/seguranca` (nova rota) + `components/SecurityMfaPanel.tsx` — cadastro (QR +
    segredo manual + código de confirmação) e step-up (login futuro já com fator verificado,
    exige só o código) num único painel, via `enroll`/`challengeAndVerify`. **Segundo (e único
    outro) lugar do app que usa o client Supabase do browser**, mesma classe de exceção do
    `/auth/confirm` (M18-G22 anterior): a interação — mostrar QR, reagir a código errado sem
    reload — só faz sentido contra a sessão viva no navegador; todo o resto do app continua
    servidor + formulário.
  - Link "🔐 Segurança" adicionado à topbar do portal pra qualquer membro ativar MFA por conta
    própria, mesmo quando não é exigido pelo papel.
- **Testes**: `tests/m18-g22-mfa-security.test.ts` (novo) — as 4 combinações de `decideMfaGate`,
  guarda-varredura confirmando que só `auth/confirm/page.tsx` e `SecurityMfaPanel.tsx` importam
  o client do browser (qualquer novo import precisa ser adicionado ali de propósito, nunca por
  acidente), e trava textual do fail-closed em `lib/mfa.ts`. `apps/portal` 86/86 (80 anteriores +
  6 novos), type-check, lint e build limpos (`next build` local — `npm test`/`build` com hook de
  versão do Node bloqueados neste ambiente por Node 26 instalado vs. `>=22 <23` pinado; rodado
  direto via `tsx`/`next` pra contornar, mesmo binário que a CI usa).
- **Ainda não fechou o portão**: isto é infraestrutura testada localmente, não a ação real do
  usuário-piloto. Faltam, na ordem: (1) commit chegar em `staging` remoto e o Vercel publicar;
  (2) dono da Mania de Modas logar de novo e ser redirecionado sozinho pra
  `/configuracoes/seguranca` (papel `owner` já tem `requires_mfa=true` desde o provisionamento);
  (3) ele de fato escanear o QR e confirmar o código — só aí a sessão chega em `aal2` de verdade
  e o G22 fecha por completo.
