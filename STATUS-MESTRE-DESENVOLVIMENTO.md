# ConnectionCyber — Status Mestre de Desenvolvimento

**Documento vivo e obrigatório**  
**Ambiente de trabalho:** staging  
**Atualizado em:** 18/08/2026  
**Versão do documento:** 1.3.0
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
- A migration `0006`, que contém povoamento de clientes reais, foi registrada no histórico de staging sem executar seus `INSERTs`.
- Vercel Production deve apontar exclusivamente para o Supabase de produção.
- Vercel Preview/branch staging deve apontar exclusivamente para o Supabase de staging.

### 4.3 Multiempresa

- Um cliente é representado por uma linha em `tenants`.
- O isolamento é realizado por `tenant_id` e Row Level Security.
- O tenant nunca pode ser aceito de formulário, query string ou payload do navegador como autoridade de acesso.
- A equipe ConnectionCyber usa papéis administrativos controlados e auditados.
- Configurações, módulos, temas, contratos e migrações são vinculados ao tenant.

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

### 5.4 Análise M01 executada

- M00 foi aprovado pelo responsável do projeto em 18/08/2026.
- O acervo `modelo exemplo` foi inventariado somente para leitura: 68 arquivos, 5.495.739 bytes, sendo 64 PNG, dois DOCX e dois TXT.
- Impressão digital agregada do manifesto: `ab936514fef1d21106217b9c7ff677a0db608d1435035cfbedcb3e9cbee8f459`.
- Nenhum backup ou banco físico foi localizado no staging (`.bak`, `.mdf`, `.ldf`, compactados ou formatos de banco conhecidos).
- As telas comprovam as funções do ERP e a conexão legada `LocalHost\SQLEXPRESS` / banco `CONNECTIONCYBER`, mas não comprovam nomes físicos de tabelas, chaves ou código armazenado.
- O ambiente local contém SQL Server 2022 Express; ele não será usado para restore de cliente. O laboratório preferencial é isolado em SQL Server 2022 Developer, sem porta pública, com cópia somente leitura e sem `WITH REPLACE`.
- O Supabase atual ainda não possui modelo ERP canônico. Tabelas do site/Mercado Pago não serão reutilizadas para produtos, vendas ou pagamentos legados.
- A lista documental tem 14 empresas, a configuração do site tem 15 posições, uma migration histórica menciona 10 e staging possui somente o tenant ConnectionCyber. O cadastro mestre deverá ser validado antes do provisionamento.
- Parecer e matriz preliminar emitidos em `PARECER-TECNICO-M01-ENGENHARIA-REVERSA.md` e `.html`.
- Estado do M01: `Bloqueado em M01-G1`, aguardando uma cópia controlada do backup representativo. Nenhuma restauração, migration, carga ou alteração de produção foi realizada.

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
| R-008 | Não há arquivo de backup no acervo analisado. | Bloqueante | Receber cópia protegida, fora do Git, registrar metadados e SHA-256 antes de inspecionar a mídia. |
| R-009 | O schema atual possui colisão semântica com nomes do futuro ERP e 16 tabelas públicas observadas sem RLS. | Crítica | Criar modelo `erp_*` isolado no M02; não carregar legado em tabelas do site, Mercado Pago ou suporte remoto. |

## 7. Programa de módulos e portões

| Ordem | Módulo/portão | Estado atual | Entrega principal | Critério para avançar |
|---:|---|---|---|---|
| M00 | Segurança e qualidade de staging | Aprovado | Migrations, variáveis, CI, Preview e smoke tests aprovados | Concluído e aceito em 18/08/2026. |
| M01 | Engenharia reversa do legado | Bloqueado em M01-G1 | Restaurar um backup representativo e gerar dicionário físico | G0 aprovado; aguarda cópia do backup para hash e custódia em G1. |
| M02 | Fundação ERP multiempresa | Não iniciado | Contratos, estabelecimentos, configurações, auditoria e isolamento | Testes cross-tenant e rollback de migration aprovados. |
| M03 | Portal do cliente e subdomínios | Não iniciado | `apps/portal`, autenticação e resolução segura de hostname | Empresa A nunca acessa empresa B; domínio desconhecido é rejeitado. |
| M04 | Usuários, RBAC e MFA | Não iniciado | Papéis, permissões por ação e convites | Matriz de acesso validada; nenhuma senha legada migrada. |
| M05 | Cadastros mestres | Não iniciado | Clientes, fornecedores, colaboradores, vendedores, transportadoras e produtos | Contagens, documentos e vínculos reconciliados. |
| M06 | Estoque e compras | Não iniciado | Depósitos, movimentos, inventário, lotes, preços e pedidos | Saldo reconstruído por movimentos coincide com o legado. |
| M07 | Vendas, orçamento e PDV | Não iniciado | Orçamentos, vendas, pagamentos, caixa e comprovantes | Totais por dia/item/pagamento e estoque/caixa reconciliados. |
| M08 | Financeiro e bancário | Não iniciado | Receber, pagar, fluxo de caixa, cartões, cheques e boletos | Saldos em aberto e liquidações coincidem com o legado. |
| M09 | Atendimento e suporte | Não iniciado | Chamados, SLA, ordens de serviço e histórico | Chamados abertos e eventos preservados e auditáveis. |
| M10 | Acesso remoto | Não iniciado | Dispositivos, autorização, sessões e auditoria | MFA, consentimento, expiração e revogação comprovados. |
| M11 | Agente local e periféricos | Não iniciado | Impressão, etiqueta, balança, TEF e certificado quando necessário | Testes físicos no ambiente piloto sem segredo exposto. |
| M12 | Fiscal e certificado A1 | Não iniciado | Perfil tributário, XML, NF-e/NFC-e e eventos | Homologação fiscal, contingência e ciclo do certificado aprovados. |
| M13 | Importador de dados | Não iniciado | Pipeline idempotente, mapa de IDs e reconciliação | Reexecução não duplica dados; relatório fecha todos os totais. |
| M14 | Cliente piloto | Não iniciado | Migração simulada e corte controlado de uma empresa | Aceite funcional, reconciliação e rollback testado. |
| M15 | Implantação por cliente | Não iniciado | Ondas individuais de migração | Checklist e aceite executados separadamente por tenant. |

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

### M01-G1 — recepção e custódia da cópia

Próxima sequência permitida:

1. revisar e aprovar o parecer técnico M01;
2. escolher o backup representativo — provisoriamente, Maria dos Remédios/Mania de Moda;
3. preservar o backup original sem alteração;
4. disponibilizar uma cópia em diretório protegido e fora do repositório Git;
5. informar empresa, data, origem, extensão, tamanho e caminho exato da cópia;
6. calcular e registrar SHA-256 sem abrir ou restaurar o arquivo;
7. validar o M01-G1 antes de executar `HEADERONLY`, `FILELISTONLY` ou `VERIFYONLY` no M01-G2.

Comando de aceite sugerido: `Parecer M01 aprovado; disponibilizar cópia do backup da Mania de Moda em [caminho] e executar M01-G1.`

Não enviar a única cópia original, senha de certificado A1 ou credenciais em mensagem. Produção e Mercado Pago real permanecem fora deste portão.

## 11. Histórico do documento

| Versão | Data | Módulo | Alteração | Resultado |
|---|---|---|---|---|
| 1.0.0 | 18/08/2026 | Governança | Criação do documento mestre com baseline, riscos, fila e critérios. | Aguardando validação do documento antes do início do M00 remoto. |
| 1.1.0 | 18/08/2026 | M00 | Banco staging, push, CI, Preview e smoke tests executados; evidências registradas. | Bloqueado na configuração privada do formulário no Vercel Preview; produção não alterada. |
| 1.2.0 | 18/08/2026 | M00 | Variável sensível corrigida, redeploy de Preview e smoke test completo com limpeza do dado sintético. | Validado em staging; aguarda aceite explícito para iniciar a análise do M01. |
| 1.3.0 | 18/08/2026 | M01 | Inventário, análise do legado/stack, matriz preliminar, laboratório seguro, rollback e portões G0–G6 documentados. | M00 aprovado; M01-G0 aprovado e M01 bloqueado em G1 por ausência da cópia do backup; produção não alterada. |

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
