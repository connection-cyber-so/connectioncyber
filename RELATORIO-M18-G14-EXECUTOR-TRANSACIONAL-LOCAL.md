# M18-G14 — executor transacional local do piloto

Data: 01/09/2026

Resultado: **APROVADO LOCALMENTE**

## Implementação

- Unidade de trabalho local com snapshot e rollback integral.
- Chave idempotente derivada do manifesto M18-G13; replay não duplica entidades.
- Tenant, estabelecimento, capacidades, membership owner e MFA/AAL2 simulados em uma fronteira atômica.
- Convite Auth convertido em outbox pendente e não executável neste gate.
- Identidades protegidas não são resolvidas nem persistidas; somente referências e fingerprints são usados.
- Modos remotos, unit of work desconhecida, tenant duplicado e referência ausente falham fechado.

## Evidências

- Marcadores: `M18_G14_LOCAL_TRANSACTION_OK` e `M18_G14_LOCAL_REPLAY_OK`.
- Seis pontos de falha comprovaram restauração exata do snapshot.
- Testes focados M18-G13/G14: 27/27.
- Plataforma: 120/120; TypeScript, ESLint e build Next.js aprovados com Node.js 22.23.2.
- Supabase, Auth, Vercel e produção não foram acessados.

## Risco residual e próximo portão

O contrato local ainda não é um executor PostgreSQL/Auth. O próximo gate deve auditar o mapeamento para as tabelas/RPCs existentes e definir a ordem segura entre transação de banco e convite Auth. Qualquer criação efetiva continuará em autorização separada.
