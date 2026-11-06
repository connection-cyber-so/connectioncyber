-- 0056 rollback. SÓ sem vínculo ativo das 3 chaves e sem uso em outro tenant.
-- Aborta se existir vínculo em erp_tenant_capabilities para as chaves novas.
-- Tudo em uma transação com ON_ERROR_STOP: se a checagem falhar, nenhum DROP é executado.
\set ON_ERROR_STOP on
begin;

do $$
begin
  if exists (select 1 from public.erp_tenant_capabilities
             where capability_key in ('cd.armazenagem', 'cd.expedicao', 'site.loja')) then
    raise exception 'rollback 0056 abortado: há vínculos de capacidade (cd.* ou site.loja) em erp_tenant_capabilities';
  end if;
end $$;

drop trigger if exists trg_erp_tenant_capabilities_deps on public.erp_tenant_capabilities;
drop function if exists public.erp_enforce_capability_dependencies();
drop table if exists public.erp_capability_dependencies;
delete from public.erp_capability_catalog where key in ('cd.armazenagem', 'cd.expedicao', 'site.loja');

commit;
