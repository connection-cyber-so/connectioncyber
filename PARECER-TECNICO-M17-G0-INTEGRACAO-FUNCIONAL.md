# M17-G0 — encerramento da industrialização e próxima trilha

Data: 31/08/2026

## Decisão executiva

O M16 está tecnicamente encerrado no escopo planejado. A plataforma possui núcleo único, catálogo de capacidades, perfis MEI/ME/LTDA, exceções tenant-scoped, aplicação da migration `0032` no staging, painel administrativo e simulador de implantação em ondas.

**Próxima trilha escolhida: M17 — integração funcional persistente da jornada operacional.**

Não é correto iniciar outro conjunto de módulos agora. A principal lacuna é conectar a experiência visual integrada de cadastro, estoque, PDV, caixa e financeiro ao backend multi-tenant já versionado. A demonstração visual permanece em memória; os módulos server-side existentes ainda não formam uma única transação operacional ponta a ponta pela interface.

## Estado técnico consolidado

| Camada | Estado | Parecer |
|---|---|---|
| Schema e RLS | migrations até `0032` validadas no staging | pronto para ensaio sintético controlado |
| Capacidades por tenant | catálogo, entitlements, exceções e resolver | concluído no M16 |
| Interface operacional | jornada visual completa e responsiva | pronta como demonstração sintética |
| Leituras server-side | serviços Supabase presentes em vários módulos | parcial |
| Escritas transacionais | ações isoladas e RPCs por módulo | parcial |
| Jornada persistente integrada | cadastro → estoque → venda → caixa → financeiro | não comprovada pela interface |
| UAT real | depende de identidade, fiscal, dados e agenda do piloto | bloqueada |
| Produção | sem go/no-go, restore drill e aceite real | bloqueada |

## Objetivo do M17

Transformar a demonstração integrada em uma aplicação funcional tenant-scoped, mantendo a mesma interface e substituindo gradualmente o estado em memória por contratos server-side, RPCs idempotentes e leituras reconciliadas.

```text
UI VALIDADA
    |
    v
Server Actions validadas + autorização por tenant/capacidade
    |
    v
RPCs transacionais idempotentes
    |
    v
PostgreSQL com RLS + ledger + auditoria
    |
    v
releitura e reconciliação da jornada completa
```

## Regras obrigatórias

1. A interface nunca define `tenant_id`, preço final, saldo ou autorização técnica.
2. Toda mutação resolve tenant, membership e capacidade no servidor.
3. Venda, estoque, caixa e financeiro usam operações idempotentes e transacionais.
4. Falha parcial resulta em rollback integral e mensagem segura.
5. Testes negativos cross-tenant acompanham cada fluxo.
6. Dados sintéticos permanecem separados e descartáveis até portão específico.
7. Produção, empresa real, A1, CSC, pagamentos e importação real continuam bloqueados.

## Sequência determinística M17

| Gate | Entrega | Escopo |
|---|---|---|
| M17-G0 | parecer e sequência | local, concluído |
| M17-G1 | contrato canônico da jornada persistente, comandos, estados e erros | local, sintético |
| M17-G2 | camada server-side de autorização, tenant e capacidades | local, testes com dublês |
| M17-G3 | cadastro e catálogo persistentes integrados à interface | local primeiro |
| M17-G4 | estoque, PDV e caixa em transação idempotente | local primeiro |
| M17-G5 | financeiro derivado e reconciliação ponta a ponta | local primeiro |
| M17-G6 | auditoria independente de segurança, concorrência e rollback | local |
| M17-G7 | ensaio remoto com tenant e fixtures sintéticos dentro de `ROLLBACK` | autorização específica |
| M17-G8 | aplicação sintética persistente no staging e UAT visual técnico | autorização específica |
| M17-G9 | parecer de prontidão para retomar o piloto M15 real | análise e novo portão |

## Critérios de conclusão

- jornada completa executada pela interface e relida do banco;
- zero confiança em identificadores enviados pelo navegador;
- isolamento cross-tenant negativo comprovado;
- repetição idempotente sem venda, estoque, caixa ou financeiro duplicados;
- falha injetada com rollback integral;
- trilha de auditoria correlaciona comando, ator, tenant e resultado;
- desktop e celular aprovados sem regressão;
- staging sintético removível e produção intacta.

## Trilha operacional real

O M15 real não foi cancelado. Ele permanece suspenso nos pontos que exigem empresa-piloto, contador, identidade real, inventário físico, backup, homologação fiscal, UAT, corte e hipercare. Ao concluir o M17, o M17-G9 decidirá se esses portões podem ser retomados.

## Próxima etapa automática

**M17-G1 — contrato canônico da jornada persistente, mapa de comandos, estados, idempotência e erros, usando somente dados sintéticos locais.**

Marcador: `M17_G0_PERSISTENT_FUNCTIONAL_TRACK_APPROVED`
