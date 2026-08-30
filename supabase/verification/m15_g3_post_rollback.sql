select
  (select count(*) from public.tenants where slug like 'm15-g3-synthetic-%') as synthetic_tenants,
  (select count(*) from auth.users where email like '%m15-g3%') as synthetic_accounts,
  (select count(*) from public.erp_fiscal_documents where tenant_id in(
    '15000000-0000-4000-8000-000000000001',
    '15000000-0000-4000-8000-000000000002',
    '15000000-0000-4000-8000-000000000003'
  )) as synthetic_fiscal_documents,
  'M15_G3_ROLLBACK_CLEAN' as result;
