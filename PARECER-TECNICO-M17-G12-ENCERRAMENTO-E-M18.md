# M17-G12 — encerramento da jornada persistente e definição do M18

Data: 31/08/2026

## Decisão executiva

O M17 está encerrado no escopo de **backend transacional persistente**. A migration `0033` foi auditada, validada com `ROLLBACK`, aplicada exclusivamente no Supabase staging e aprovada por 96/96 asserções pós-aplicação.

O M17 não autoriza ainda piloto real nem produção. A inspeção do código confirmou que a interface operacional não chama as sete RPCs `erp_command_*_v1`; os fluxos visuais permanecem locais ou sintéticos. O critério original “executar pela interface e reler do banco” será concluído no próximo módulo, sem enfraquecer o aceite.

**Próximo módulo cronológico: M18 — integração visual persistente e UAT sintético.**

## Estado consolidado do M17

| Camada | Estado | Evidência |
|---|---|---|
| Contrato canônico | concluído | sete comandos, estados, erros e idempotência |
| Autorização server-side | concluída localmente | tenant, membership, capacidade e permissão fail-closed |
| Aplicações locais | concluídas | cadastro, catálogo, estoque, PDV, caixa e financeiro |
| Auditoria adversarial | concluída | concorrência, replay, isolamento e rollback |
| Persistência PostgreSQL | concluída em staging | migration `0033/0033` |
| Segurança da migration | concluída | RLS, privilégios mínimos, hash e payload protegidos |
| Testes PostgreSQL | concluídos | 96/96 pós-aplicação |
| Interface chamando RPCs 0033 | não iniciada | nenhuma referência encontrada em `apps/platform/src` |
| UAT visual persistente | pendente | transferido para M18 |
| Piloto e produção | bloqueados | dependem de M18 e dos portões reais M15 |

## Sequência determinística M18

| Gate | Entrega | Escopo |
|---|---|---|
| M18-G0 | contrato da integração visual persistente, estados de carregamento, erros e ameaça | local |
| M18-G1 | cliente server-side tipado para as sete RPCs e read models tenant-scoped | local, dublês |
| M18-G2 | cadastro de cliente e produto conectado à fronteira persistente | local primeiro |
| M18-G3 | estoque, abertura de caixa e PDV conectados à fronteira persistente | local primeiro |
| M18-G4 | financeiro, fechamento de caixa, dashboard e reconciliação por releitura | local primeiro |
| M18-G5 | auditoria independente de autorização, cross-tenant, replay e UX de falha | local |
| M18-G6 | ensaio remoto descartável com fixtures sintéticas e `ROLLBACK` | autorização específica |
| M18-G7 | ambiente sintético persistente de UAT no staging | autorização específica |
| M18-G8 | UAT visual desktop/celular, acessibilidade e parecer de retomada do M15 | staging controlado |

## Critérios de conclusão do M18

1. A interface não envia `tenant_id`, preço autoritativo, saldo ou permissão.
2. Os sete comandos passam exclusivamente pela fronteira server-side.
3. Toda tela relê estado persistido após a mutação; estado otimista nunca é autoridade.
4. Replay não duplica cadastro, estoque, venda, caixa ou financeiro.
5. Falha parcial e troca de tenant resultam em bloqueio seguro e mensagem sem detalhes internos.
6. Desktop e celular executam a jornada sintética completa no staging.
7. Fixtures de UAT são identificáveis, removíveis e separadas de qualquer empresa real.

## Limites preservados

- Nenhum dado real, conta, fixture ou tenant foi criado neste gate.
- Nenhum acesso ao Supabase, Vercel, GitHub remoto ou produção.
- Fiscal real, A1, CSC, pagamentos reais, importação real e corte continuam bloqueados.
- O piloto M15 permanece suspenso até o parecer M18-G8.

Marcador: `M17_G12_BACKEND_PERSISTENT_TRACK_CLOSED_M18_DEFINED`.

Próxima etapa automática: **M18-G0 — contrato da integração visual persistente, mapa de telas/comandos/read models, modelo de ameaças e testes locais.**
