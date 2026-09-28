# M17-G6 — auditoria independente da jornada integrada

Data: 31/08/2026

## Escopo

Auditoria local adversarial dos componentes M17-G1 a M17-G5 em segurança, concorrência, idempotência e rollback. Somente dados sintéticos; nenhum serviço remoto foi acessado.

## Bloqueios encontrados e remediados

1. **Campos de autoridade sensíveis a caixa:** aliases como `TenantId` e `ActorID` poderiam escapar da triagem lexical. A comparação agora é normalizada e fail-closed.
2. **Projeção financeira antes da validação completa:** a reconciliação agora opera em cópia isolada e publica o mapa somente após validar vendas, lançamentos e órfãos.
3. **Leitura financeira sem fronteira:** a aplicação deixou de expor reconciliação por `tenantId`; a superfície pública aceita somente comando autorizado por host, sessão, membership, permissão e capacidade.

## Provas adversariais

- duas vendas concorrentes idênticas produzem um efeito e um replay;
- vendas concorrentes divergentes com a mesma chave aplicam somente uma;
- baixas concorrentes idênticas liquidam uma única vez;
- baixas concorrentes acima do saldo aplicam somente a operação válida;
- mutação do comando após autorização é detectada pelo hash antes do repositório;
- aliases de autoridade são bloqueados sem diferenciar maiúsculas;
- rollback e evidências permanecem locais, sem persistência ou rede.

## Resultado

- 116/116 testes do pacote aprovados com Node.js 22.23.2.
- Simulação financeira aprovada: `M17_G5_LOCAL_FINANCE_RECONCILIATION_OK`.
- Plataforma: 32/32 testes, TypeScript, ESLint e build aprovados.
- `node --check` aprovado nos arquivos remediados e na suíte adversarial.
- Supabase, Vercel, GitHub remoto, rede e produção não acessados.

## Parecer

A jornada local está aprovada para o próximo gate de desenho da persistência. Concorrência distribuída real ainda exigirá constraints, locks ou controle otimista no PostgreSQL; esta auditoria não autoriza persistência remota.

Marcador: `M17_G6_INDEPENDENT_LOCAL_AUDIT_OK`

Próxima etapa automática: M17-G7 — contrato de persistência PostgreSQL/Supabase, transações, constraints e RPCs, sem criar migration nem acessar remoto.
