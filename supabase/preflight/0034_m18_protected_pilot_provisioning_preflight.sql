begin transaction read only;
do $$begin
  if to_regclass('public.erp_identity_provisioning_runs')is null or to_regclass('public.erp_identity_provisioning_steps')is null or to_regclass('public.erp_establishments')is null or to_regclass('public.erp_tenant_capabilities')is null then raise exception '0034 baseline missing';end if;
  if to_regclass('public.erp_auth_invitation_outbox')is not null or to_regclass('public.erp_auth_identity_compensations')is not null or exists(select 1 from information_schema.columns where table_schema='public'and table_name='erp_establishments'and column_name='state_registration')then raise exception '0034 already present';end if;
  if to_regprocedure('public.erp_set_tenant_capability(uuid,text,text,text,integer,text,timestamp with time zone,timestamp with time zone)')is null then raise exception '0034 capability RPC missing';end if;
  if exists(select 1 from public.tenants where dominio is not null group by lower(dominio)having count(*)>1)then raise exception '0034 duplicate tenant domains';end if;
  if exists(select 1 from unnest(array['core.parties','core.catalog','inventory.stock','sales.pos','finance'])k where not exists(select 1 from public.erp_capability_catalog c where c.key=k and c.active))then raise exception '0034 pilot capability missing';end if;
end$$;
rollback;
select 'M18_0034_PREFLIGHT_OK' as marker;
