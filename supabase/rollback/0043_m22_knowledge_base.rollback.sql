-- Operational rollback: KNOWLEDGE_BASE_ENABLED=false, preserve all data.
-- Destructive SQL intentionally not automated. Forward-fix for shared environments.
-- Confirm no active clients before changing permissions; this transaction disables commands.
begin;
revoke execute on function public.kb_command(uuid,text,uuid,integer,jsonb) from authenticated;
commit;
-- Re-enable only after repair and security tests:
-- grant execute on function public.kb_command(uuid,text,uuid,integer,jsonb) to authenticated;
