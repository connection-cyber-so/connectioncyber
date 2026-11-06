-- Rollback 0053_tenant_domains.
-- Uso: somente em laboratório descartável OU quando tenant_domains estiver vazia.
-- Em banco remoto, preferir forward-fix (ver apps/portal/README.md).

begin;

do $$
begin
  if to_regclass('public.tenant_domains') is not null
     and exists (select 1 from public.tenant_domains) then
    raise exception 'ROLLBACK_0053_RECUSADO: tenant_domains tem linhas. Forward-fix obrigatório.';
  end if;
end
$$;

drop function if exists public.resolve_tenant_by_host(text);
drop table if exists public.tenant_domains;

commit;
