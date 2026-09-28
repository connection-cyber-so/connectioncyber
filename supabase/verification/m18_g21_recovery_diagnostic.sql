begin transaction read only;
select
  (select count(*) from public.tenants where slug='maniademodas') as tenant_count,
  (select count(*) from public.erp_establishments e join public.tenants t on t.id=e.tenant_id where t.slug='maniademodas') as establishment_count,
  (select count(*) from public.erp_identity_provisioning_runs where idempotency_key='pilot:staging:m18-g21:maniademodas-v1') as run_count,
  (select coalesce(max(status),'absent') from public.erp_identity_provisioning_runs where idempotency_key='pilot:staging:m18-g21:maniademodas-v1') as run_status,
  (select count(*) from public.erp_auth_invitation_outbox o join public.tenants t on t.id=o.tenant_id where t.slug='maniademodas') as outbox_count,
  (select coalesce(max(o.status),'absent') from public.erp_auth_invitation_outbox o join public.tenants t on t.id=o.tenant_id where t.slug='maniademodas') as outbox_status,
  (select count(*) from public.erp_tenant_memberships m join public.tenants t on t.id=m.tenant_id where t.slug='maniademodas') as membership_count,
  (select count(*) from public.erp_auth_identity_compensations c join public.tenants t on t.id=c.tenant_id where t.slug='maniademodas') as compensation_count;
rollback;
