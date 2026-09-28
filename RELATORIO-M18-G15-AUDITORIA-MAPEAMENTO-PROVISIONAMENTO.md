# M18-G15 — auditoria do mapeamento PostgreSQL/Auth

Data: 01/09/2026

Resultado: **MAPEAMENTO APROVADO; CRIAÇÃO EFETIVA BLOQUEADA**

## Mapeamento confirmado

- Dez alvos: tenant, estabelecimento, capacidades, Auth, profile, membership, role, vínculo, run e step.
- `auth.users` cria somente `public.users`; tenant nunca vem de metadata ou JWT.
- Membership é a autoridade tenant-scoped; owner exige MFA/AAL2.
- Capacidades são ativadas pela RPC broker-only `erp_set_tenant_capability`.
- Ledger de provisionamento é server-only e sem policies para navegador.

## Ordem segura

1. Resolver referências protegidas somente em memória e validar ausências.
2. Abrir ledger e gravar tenant, estabelecimento, roles, capacidades e outbox na mesma transação PostgreSQL.
3. Confirmar a transação antes de chamar Supabase Auth.
4. Despachar convite idempotente; depois vincular profile, membership e roles em nova transação.
5. Exigir AAL2, concluir ledger e executar pós-verificação.

## Seis bloqueios

- Não existe RPC atômica de provisionamento.
- A allowlist de ações do ledger não cobre tenant, estabelecimento, capacidades e outbox.
- Não existe outbox durável de convite Auth.
- Auth e PostgreSQL não compartilham transação.
- `erp_establishments` não possui inscrição estadual.
- Não existe contrato de compensação para identidade Auth órfã.

## Evidências

- Marcador: `M18_G15_MAPPING_AUDIT_OK`.
- Auditoria focada: 7/7; plataforma: 127/127.
- TypeScript, ESLint e build aprovados em Node.js 22.23.2.
- Nenhum serviço remoto acessado e nenhum dado criado.

## Próximo gate

M18-G16 — remediar localmente os seis bloqueios por migration `0034`, RPC server-only, outbox, inscrição estadual, compensação, preflight, rollback e pgTAP. Aplicação remota continuará bloqueada.
