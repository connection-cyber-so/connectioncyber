-- PREFLIGHT 0069 · PDV · auditoria do PIN e auto-PIN do gerente
-- Somente leitura. Rodar antes de aplicar 0069 (estado 0068).
-- Sem exceção = pronto para aplicar.

do $$
begin
  if to_regprocedure('public.erp_manager_set_approver_pin(uuid,uuid,text)') is null then
    raise exception 'PREFLIGHT 1 FALHOU: erp_manager_set_approver_pin ausente (aplicar 0068 antes)';
  end if;
  if to_regclass('public.erp_approver_pin_audit') is not null then
    raise exception 'PREFLIGHT 2 FALHOU: erp_approver_pin_audit já existe';
  end if;
  if to_regclass('public.erp_approver_pins') is null
     or to_regclass('public.erp_tenant_settings') is null
     or to_regclass('public.erp_tenant_memberships') is null
     or to_regclass('public.tenants') is null
     or to_regclass('public.users') is null then
    raise exception 'PREFLIGHT 3 FALHOU: tabela de dependência ausente';
  end if;
  if to_regprocedure('erp_security.has_permission(uuid,text)') is null
     or to_regprocedure('public.is_platform_staff()') is null then
    raise exception 'PREFLIGHT 4 FALHOU: função de permissão ausente';
  end if;
  if exists (
    select 1 from public.erp_tenant_settings where key = 'pdv.alcada.allow_self_pin' and establishment_id is null
  ) then
    raise notice 'PREFLIGHT 5: configuração pdv.alcada.allow_self_pin já existe (seed será ignorado)';
  end if;
  raise notice 'PREFLIGHT 0069 OK';
end
$$;
