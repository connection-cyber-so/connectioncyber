-- ConnectionCyber — hardening de funções legadas expostas.
begin;

alter function public.set_updated_at() set search_path = '';

-- O painel chama esta função somente após autenticação. Anon nunca precisa dela.
revoke execute on function public.is_platform_staff() from public, anon;
grant execute on function public.is_platform_staff() to authenticated, service_role;

commit;
