# PARECER TÉCNICO M15-G0 — Prontidão do piloto (Mania de Modas)

Data: 29/09/2026
Escopo: parecer de prontidão, **sem criar dados reais, sem acessar produção** (conforme
definição do `PARECER-TECNICO-M14-G8-ENCERRAMENTO-E-M15.md`). Evidências levantadas no
Supabase staging `ozvylnaipubrmaadikvk` em 29/09/2026.

## 1. Matriz de prontidão — empresa-piloto Mania de Modas

| Item | Estado em 29/09/2026 | Pronto? |
|---|---|---|
| Tenant ativo + vertical `varejo-moda-calcados` | ativo, `slug=maniademodas` | sim |
| Domínio do tenant | `maniademoda.connectioncyber.com.br` (resolve `66.33.60.130`) | parcial¹ |
| Estabelecimento | 1 ativo | sim |
| Membership / identidade | 2 ativas + 1 revogada; usuária-piloto com senha e **MFA/TOTP** em AAL2 (M18-G22) | sim |
| Capacidades (capabilities) | 20 ativas na plataforma (tenant incluído) | sim |
| Catálogo (`products`) | **0 produtos em toda a plataforma** | não |
| Importação de legado | ledger do piloto não carregado; **3 jobs concluídos** só nos tenants do M14-G9 (Rose/Casa/CSC) | não |
| Materialização de entidades | tabelas `erp_people`/`erp_sales`/etc. **não existem** | não |
| Emissão fiscal | 0 documentos, 0 séries, 0 reservas, 0 transmissões | não |
| Entrega ao contador (M24) | 0 eventos; rota `/fiscal/contador` pronta | não |
| Assinatura SaaS (M25) | plano `padrao` cadastrado, **0 assinaturas, 0 checkouts** | não |
| Backup/R-003 | rotina corrigida e restore provado (21/21, 28/09); **nunca agendada** | parcial |

¹ O piloto aponta para `66.33.60.130` enquanto os demais `*.connectioncyber.com.br` apontam
para `76.76.21.x` — alvos diferentes; confirmar que ambos são o mesmo projeto de deploy
antes de qualquer corte.

## 2. Inventário de bloqueios

| Área | Bloqueio | Severidade | Libera em |
|---|---|---|---|
| **Fiscal** | Validação cadastral/tributária do contador pendente (esperada desde 31/08/2026, sem resposta registrada); nenhum documento emitido | **crítica** (corte) | M15-G5 + resposta do contador |
| **Usuários** | Rose Variedades e CSC Distribuidora com **0 memberships** — steps `m18.05 finalize_identity` e `m18.06 require_mfa` em `planned` (convite enfileirado, sem identidade); Casa de Bolos e Loja da Benção completos até `m18.05` | alta | M15-G3 (**requer autorização**: criar usuários reais) |
| **Credenciais** | Token CLI do staging (`connectioncyber-cli-m23`, 7 dias, emitido 27/09) expira por volta de 04/10; 5 `.pfx`+`.p12` **com senha no nome do arquivo** no acervo (incidente latente) | alta | renovar token; custódia dos PFX |
| **Domínio** | 5 subdomínios públicos ativos; divergência de alvo (item ¹ acima) | média | M15-G2 |
| **Backup** | RPO 24h **manual** (sem agendador autorizado); dumps R-003 existem só em `%TEMP%` da máquina local | média | agendar/rotina manual |
| **Operação** | Catálogo vazio (0 produtos); log de execução só local (`staging/logs`, fora do Git); nenhum dado de venda para validar | média | M15-G1/G2 |

## 3. Plano de ambientes, backup, restauração, corte e rollback (por tenant)

**Ambientes** — um único banco por ambiente, nunca compartilhar: `staging ozvylnaipubrmaadikvk`
(desenvolvimento/homologação, **único autorizado para dados reais de importação**),
`produção` (intocada até corte autorizado), laboratório isolado (`supabase start` local)
para restaurações.

**Backup** — rotina `scripts/backup-connectioncyber-staging.ps1` (schema + data, SHA-256
registrado), cadência manual diária (RPO 24h); `docs/runbooks/PILOT-BACKUP-RESTORE.md`
com RTO 4h contratual / 8,4s medido.

**Restauração** — `scripts/verify-restore-r003.ps1` (21/21 PASS, imagem 17.6 isolada);
nunca `drop schema auth cascade` em restauração parcial.

**Corte por tenant** (só após autorização e critérios da seção 4): (1) snapshot final de
backup; (2) congelar escrita (maintenance do app); (3) delta final de importação
(idempotente, replay); (4) provisionar identidades + MFA; (5) abrir escrita; (6) smoke de
jornada; (7) janela de observação de 24h.

**Rollback** — (1) restaurar snapshot do passo 1 no ambiente anterior; (2) reverter
`erp_import_jobs` para `rolled_back` apenas em lote novo (nunca apagar ledger reconciliado);
(3) identidades criadas no corte → `revoked` (membership), não apagar `auth.users`.

## 4. Critérios de aceite

- **Funcionais**: jornada completa login → catálogo → PDV → venda gravada com RLS isolado
  por tenant; importação do tenant com `14/14`-estilo (`reconciliados == lotes`,
  `bloqueados = 0`).
- **Financeiros**: soma das vendas do dia = soma dos itens (centavos); assinatura M25 cobra
  o valor do plano no primeiro pagamento aprovado e provisiona o tenant automaticamente.
- **Fiscais**: NF-e transmitida com protocolo `cStat=100`, XML arquivado e entrega ao
  contador com `manifest SHA-256` + recibo (M24). **Bloqueado** até o contador.
- **Segurança**: todo owner com MFA ativo em AAL2; REST anônimo 200 sem `42501`; nenhum
  dado pessoal em log ou repositório (padrão M21-G7/M14-G9).
- **Desempenho**: carga de um lote de 1.000 registros < 60s (medido: 10,4s no lote real da
  Rose); abertura de tela do portal < 2s em rede normal.

## 5. Sequência M15-G1 em diante (determinística)

| Gate | Entrega | Tipo |
|---|---|---|
| **M15-G1** | Materialização de entidades: migration cria `erp_people`/`erp_products`/`erp_sales`/…, popula a partir do ledger reconciliado, com reconciliação de conferência | automático |
| **M15-G2** | Catálogo/estoque reais por tenant + conferência domínio/deploy | automático |
| **M15-G3** | Identidades Auth + convite + MFA dos responsáveis (Rose, CSC e demais) | **requer autorização** (usuários reais) |
| **M15-G4** | Jornada de venda com usuário real logado (PDV, caixa, relatório) | **requer usuário** |
| **M15-G5** | 1ª entrega fiscal ao contador (M24) após resposta do contador | **requer contador** |
| **M15-G6** | 1ª assinatura/cobrança real (M25) | **requer pagamento** |
| **M15-G7** | Corte + aceite + janela de observação 24h | **requer autorização** |

## 6. Parecer

O projeto está **pronto para M15-G1/G2** (ações automáticas, staging, sem usuários reais).
M15-G3 em diante depende de autorização explícita para usuários reais, contador, pagamento
e corte — nenhum deles está autorizado por este parecer.

Bloqueios críticos a acompanhar: resposta do contador (fiscal) e renovação do token CLI do
staging (expira ~04/10/2026).
