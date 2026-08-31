# M16-G3 — migration local 0032

Data: 30/08/2026

## Entrega

- migration `0032_m16_tenant_capabilities.sql`;
- catálogo global com 12 capacidades e classificação de risco;
- entitlements e exceções separados por `tenant_id`;
- precedência de exceção `deny` na resolução;
- RLS ativa nas três tabelas;
- escrita direta restrita ao `service_role`;
- RPC de leitura protegida por permissão;
- preflight determinístico e suíte pgTAP transacional.

## Validação local

- SHA-256: `a1a8feed5dffa94984bb0572c809bccf20f503b225044a5048da057835d53e01`;
- 48 asserções pgTAP declaradas;
- 49/49 testes Node.js e estáticos aprovados;
- Node.js 22.23.2;
- ensaio termina obrigatoriamente em `ROLLBACK`;
- nenhuma conta, identidade fiscal ou dado real incluído.

## Limite

A migration não foi executada contra PostgreSQL ou Supabase. A validação transacional remota permanece bloqueada até auditoria e remediação local do M16-G4, seguidas de autorização específica.

## Marcador

`M16_G3_MIGRATION_0032_LOCAL_READY`
