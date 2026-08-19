-- ConnectionCyber — M03 — rollback destrutivo SOMENTE para laboratório descartável
--
-- NÃO executar em Supabase staging ou produção.
-- Depois de aplicação remota, qualquer correção deve ser uma nova migration forward-fix.
--
-- Confirmações obrigatórias na mesma sessão:
--   set app.execution_environment = 'LOCAL-DISCARDABLE-LAB';
--   set app.m03_rollback_confirmation = 'DROP-M03-WITHOUT-DOMAIN-DATA';

begin;

do $$
declare
  domain_count bigint;
begin
  if current_setting('app.execution_environment', true)
       is distinct from 'LOCAL-DISCARDABLE-LAB'
     or current_setting('app.m03_rollback_confirmation', true)
       is distinct from 'DROP-M03-WITHOUT-DOMAIN-DATA' then
    raise exception 'M03_ROLLBACK_BLOCKED: confirmações explícitas ausentes.';
  end if;

  select count(*) into domain_count from public.erp_tenant_domains;
  if domain_count <> 0 then
    raise exception
      'M03_ROLLBACK_BLOCKED: % domínios existem; crie uma migration forward-fix.',
      domain_count;
  end if;
end
$$;

drop policy if exists tenants_select_erp_membership on public.tenants;
drop function if exists public.portal_resolve_host(text);
drop table if exists public.erp_tenant_domains;
drop function if exists erp_security.normalize_hostname(text);

commit;
