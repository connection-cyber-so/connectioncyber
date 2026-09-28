-- Operational rollback: disable academy commands; preserve all data.
-- Destructive SQL intentionally not automated. Forward-fix for shared environments.
begin;
revoke execute on function public.academy_command(uuid,text,uuid,jsonb) from authenticated;
revoke execute on function public.academy_context(uuid) from authenticated;
commit;
-- Re-enable only after repair and security tests:
-- grant execute on function public.academy_command(uuid,text,uuid,jsonb) to authenticated;
-- grant execute on function public.academy_context(uuid) to authenticated;
