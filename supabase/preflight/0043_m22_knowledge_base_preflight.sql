-- Read-only; inspect output before apply. Existing kb objects must be absent.
select version();
select to_regprocedure('erp_security.is_tenant_member(uuid)') as membership_helper,
 to_regprocedure('erp_security.has_permission_at_aal(uuid,text,text)') as permission_helper,
 to_regclass('storage.objects') as storage_objects,
 to_regclass('public.kb_items') as collision_items;
select id,public from storage.buckets where id='knowledge-base';
select policyname,cmd,qual,with_check from pg_policies where schemaname='storage' and tablename='objects';
-- STOP if any existing broad storage policy grants access to all buckets.
