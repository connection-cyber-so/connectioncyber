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

- SHA-256 normalizado após compatibilização com a migration 0016: `237485033a7484147315adeda8184b837298e55982c9741f86cd9e7418c7e3f3`;
- 60 asserções pgTAP declaradas;
- 54/54 testes Node.js e estáticos aprovados;
- Node.js 22.23.2;
- ensaio termina obrigatoriamente em `ROLLBACK`;
- nenhuma conta, identidade fiscal ou dado real incluído.

## Limite

A migration não foi executada contra PostgreSQL ou Supabase. A validação transacional remota permanece bloqueada até auditoria e remediação local do M16-G4, seguidas de autorização específica.

## Marcador

`M16_G3_MIGRATION_0032_LOCAL_READY` — normalizado após M16-G4.
