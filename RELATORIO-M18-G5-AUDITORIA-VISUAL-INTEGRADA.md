# M18-G5 — auditoria local independente da jornada visual

Data: 31/08/2026

## Escopo auditado

- isolamento por tenant em comandos e releituras;
- replay, idempotência e conflito de payload;
- concorrência de estoque, recebíveis e caixa;
- atomicidade da venda e das baixas;
- estados UX, duplo clique e releitura pós-comando.

## Achados e remediações

1. **Tenant de escrita não era conferido pelo transporte local.** Remediado com bloqueio `ACCESS_DENIED` antes de qualquer mutação.
2. **Replays não eram memorizados no dublê local.** Remediado com receipts por request ID, RPC e hash; replay idêntico retorna o resultado anterior e conflito falha fechado.
3. **Fechamento não comparava o ID recebido com o caixa aberto.** Remediado com validação conjunta de status e identidade da sessão.

As guardas de estoque, saldo financeiro, cliente do crediário e caixa são executadas antes das mutações. O transporte local não contém `await` entre guarda e mutação, preservando a unidade crítica no processo Node.js.

## Evidências

- Auditoria independente adicionada: 12 controles.
- Plataforma: 74/74 testes.
- Contrato visual: 49/49 testes.
- TypeScript: aprovado.
- ESLint: aprovado.
- Build Next.js com Node.js 22: aprovado.
- Achados críticos/altos residuais no escopo local: zero.

## Limites

- O estado permanece sintético, efêmero e restrito a um processo local.
- Esta aprovação não substitui testes transacionais contra PostgreSQL/Supabase.
- Nenhum serviço remoto ou ambiente de produção foi acessado.

Marcador: `M18_G5_LOCAL_INDEPENDENT_AUDIT_OK`

Próximo gate: M18-G6 — substituir o transporte sintético pelo adaptador PostgreSQL/Supabase em modo controlado, inicialmente com contrato, dublês e testes locais; acesso remoto continua bloqueado.
