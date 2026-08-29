# M15-G0 — Prontidão da empresa-piloto

Data: 29/08/2026

Empresa-piloto técnica: `pilot-maniademoda`

Subdomínio planejado: `maniademoda.connectioncyber.com.br`

Escopo desta etapa: análise e planejamento, sem contas, dados, DNS, transmissão fiscal ou produção.

## Decisão executiva

**Liberada somente para preparação sintética. Bloqueada para UAT real e produção.**

A arquitetura multiempresa, os módulos de negócio, o motor fiscal global e a fundação do importador estão validados em staging. Os bloqueios restantes pertencem à configuração individual e à operação segura do piloto.

## Matriz de prontidão

| Área | Estado | Evidência | Condição para avançar |
|---|---|---|---|
| Isolamento por tenant | Pronto em staging | RLS e testes cross-tenant dos módulos | Repetir testes no tenant sintético do piloto |
| Importador | Pronto em staging | 0031 aplicada; 96/96; zero dados | Receber fonte somente em cadeia de custódia separada |
| Motor fiscal | Condicional | Motor global, schemas, assinatura e TLS validados | Confirmar 13 requisitos fiscais e homologação individual |
| Regime tributário | Condicional | Regime Normal/RPA conhecido | Contador confirmar CRT, CST, NCM, CFOP e operação em 31/08/2026 |
| Autenticação/MFA | Bloqueado | Staging ainda tem política fraca e TOTP desabilitado | Endurecer Auth e exigir MFA privilegiado |
| Backup/restauração | Bloqueado | RPO/RTO e restauração ainda não comprovados | Executar restauração mensurável e aprovar RPO/RTO |
| Fonte legada | Bloqueado | Nenhuma cópia protegida recebida | M15-G5 com hash, mídia imutável e laboratório isolado |
| Dispositivos/offline | Bloqueado | Inventário físico não confirmado | Identificar impressora, balança, gaveta, TEF e internet |
| DNS/subdomínio | Condicional | Host explícito já definido | Validar domínio sem mudar nameservers; TTL e rollback |
| Pagamentos reais | Bloqueado | Fluxo real e webhook de produção fora do escopo | Homologar credenciais, assinatura e reconciliação |
| Observabilidade/suporte | Condicional | Auditoria técnica disponível | Definir alertas, responsáveis, escalonamento e hipercare |

## Riscos prioritários

| ID | Risco | Nível | Controle obrigatório |
|---|---|---:|---|
| M15-R1 | usuário ou suporte acessar tenant incorreto | Crítico | host + membership + RLS + testes negativos + trilha de auditoria |
| M15-R2 | corte sem restauração comprovada | Crítico | backup imutável, restore drill, RPO/RTO e rollback cronometrado |
| M15-R3 | configuração fiscal incorreta | Crítico | confirmação contábil, preflight individual e homologação antes da produção |
| M15-R4 | duplicidade ou perda na migração | Crítico | lote idempotente, reconciliação por contagem/valor e delta controlado |
| M15-R5 | indisponibilidade de internet ou periférico parar o PDV | Crítico | inventário físico, política offline e teste fail-closed por dispositivo |
| M15-R6 | credencial, A1, CSC ou PII vazar | Crítico | cofre externo, referência opaca, mascaramento e proibição em Git/log/browser |
| M15-R7 | DNS interromper site ou e-mail | Alto | subdomínio explícito, sem troca de nameserver, TTL e rollback |
| M15-R8 | usuário real criado antes do ambiente seguro | Alto | tenant sintético primeiro; conta real somente após Auth/MFA aprovado |
| M15-R9 | pagamento real sem reconciliação | Crítico | homologação, webhook autenticado, ledger e teste de estorno |
| M15-R10 | ausência de suporte durante o corte | Alto | janela, responsáveis, alertas, canal de incidente e hipercare |

## Critérios de aceite

1. Segurança: zero acesso cross-tenant; MFA privilegiado; nenhum segredo exposto; ações administrativas auditadas.
2. Funcional: cadastro, estoque, venda, caixa, financeiro, serviço aplicável e fechamento passam nos cenários críticos.
3. Dados: origem imutável; contagens e valores reconciliados; replay sem duplicação; exceções formalmente aceitas.
4. Fiscal: cadastro confirmado; homologação aprovada; A1/CSC sob custódia; produção bloqueada até go/no-go.
5. Operação: backup/restauração aprovados; RPO/RTO aceitos; monitoramento, suporte, corte e rollback testados.

## Sequência determinística M15

| Portão | Execução | Entrega | Intervenção necessária |
|---|---|---|---|
| M15-G1 | Automática | baseline de segurança pré-piloto e plano de remediação | Não, enquanto não alterar serviços remotos |
| M15-G2 | Automática | tenant totalmente sintético e ensaio ponta a ponta | Portão antes de persistir tenant no staging |
| M15-G3 | Interativa | inventário de equipamentos, rede e política offline | Acesso físico e escolhas operacionais |
| M15-G4 | Interativa | configuração fiscal protegida e homologação individual | Contador, credenciais e autorização fiscal separada |
| M15-G5 | Interativa | recebimento protegido da fonte legada | Caminho da cópia, cadeia de custódia e autorização |
| M15-G6 | Controlada | migração real ensaiada em staging e reconciliada | Autorização para dados reais no staging |
| M15-G7 | Controlada | UAT com usuários e aceite | Identidades reais e agenda do cliente |
| M15-G8 | Controlada | ensaio de corte e rollback cronometrado | Janela operacional e backup aprovado |
| M15-G9 | Decisão | go/no-go de produção | Aceite formal ConnectionCyber, cliente e fiscal |
| M15-G10 | Controlada | corte de produção | Autorização explícita e janela aprovada |
| M15-G11 | Operacional | hipercare, métricas, aceite final e lições | Acompanhamento do cliente |

## Próxima ação automática

M15-G1: auditoria da baseline de segurança pré-piloto, cobrindo Auth/MFA, RLS residual, backups, variáveis, CI/CD, Vercel, domínio, observabilidade, dependências e runbooks. A etapa deve produzir remediações locais e separar qualquer alteração remota em portões explícitos.
