do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0042' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0042 para continuar.';
  end if;
end $$;
begin;

-- Reverte a função nova e o índice único ajustado desta migration. Não mexe em nenhum
-- estabelecimento já criado por ela em ambiente real — provisionamento aplicado fica
-- intacto; forward-fix é preferido (protocolo staging-first), este rollback existe só para
-- o caso de nunca ter sido usada em produção real de dado (laboratório local descartável).
drop function if exists public.erp_prepare_pilot_establishment_v1(text, jsonb);

drop index if exists public.erp_establishments_tenant_state_registration_unique;
create unique index erp_establishments_tenant_state_registration_unique
  on public.erp_establishments(tenant_id, state_registration)
  where state_registration is not null;

commit;
