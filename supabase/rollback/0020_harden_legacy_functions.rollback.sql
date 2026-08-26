do $$
begin
  if current_setting('app.rollback_confirmation', true) <> 'ROLLBACK_0020' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0020 para continuar.';
  end if;
end
$$;

begin;
alter function public.set_updated_at() set search_path = public;
grant execute on function public.is_platform_staff() to public, anon;
commit;
