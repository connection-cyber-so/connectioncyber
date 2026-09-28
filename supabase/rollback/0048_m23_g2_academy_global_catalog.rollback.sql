-- Operational rollback: desliga a sincronia C+ e os comandos da academia preservando dados.
-- Destructive SQL intentionally not automated. Forward-fix for shared environments.
begin;
drop trigger if exists trg_academy_courses_sync on public.academy_courses;
drop trigger if exists trg_tenant_modules_academy_sync on public.tenant_modules;
drop trigger if exists trg_tenants_academy_sync_insert on public.tenants;
drop trigger if exists trg_tenants_academy_sync_vertical on public.tenants;
revoke execute on function public.academy_sync_links(uuid) from authenticated;
revoke execute on function public.academy_command(uuid,text,uuid,jsonb) from authenticated;
revoke execute on function public.academy_context(uuid) from authenticated;
commit;
-- Re-enable only after repair and security tests:
-- create trigger trg_academy_courses_sync after insert or update or delete on public.academy_courses for each row execute function public.academy_sync_links_trg();
-- grant execute on function public.academy_sync_links(uuid) to authenticated;
-- grant execute on function public.academy_command(uuid,text,uuid,jsonb) to authenticated;
-- grant execute on function public.academy_context(uuid) to authenticated;
