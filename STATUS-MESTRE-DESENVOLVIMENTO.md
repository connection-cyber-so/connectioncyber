# ConnectionCyber — Status Mestre de Desenvolvimento

**Documento vivo e obrigatório**

**Ambiente de trabalho:** staging

**Atualizado em:** 19/08/2026

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
| M13 | Fiscal e certificado A1 | G11 local concluído | Chave/DV, totais, enviNFe e lote idempotente; 148 testes | Autorizar simulador local do ciclo de autorização NF-e, sem rede. |
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

### M13-G12 — ciclo local de autorização NF-e

Próxima sequência local e automática:

1. modelar recebimento, processamento, autorização e rejeição do lote;
2. simular timeout e consulta posterior sem duplicar emissão;
3. tratar duplicidade de NF-e e protocolo já existente;
4. reconciliar estado local e resposta fiscal deterministicamente;
5. manter rede, NFC-e/CSC e produção em portões independentes.

Nenhuma migration remota será iniciada sem autorização específica. Instalação física, TEF, fiscal e produção permanecem em portões separados.

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
