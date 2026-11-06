-- Preflight 0053_tenant_domains (somente leitura). Esperado antes de aplicar:
--   1. tenants existe;   2. tenant_domains NÃO existe;   3. resolve_tenant_by_host NÃO existe.
-- Saída: uma linha por verificação, valor esperado na última coluna.

select 'tenants existe' as verificacao,
       to_regclass('public.tenants') is not null as resultado,
       true as esperado
union all
select 'tenant_domains ainda não existe',
       to_regclass('public.tenant_domains') is null,
       true
union all
select 'resolve_tenant_by_host ainda não existe',
       to_regproc('public.resolve_tenant_by_host') is null,
       true;
