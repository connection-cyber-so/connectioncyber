do $$
begin
  if to_regprocedure('public.set_updated_at()') is null
     or to_regprocedure('public.is_platform_staff()') is null then
    raise exception 'M0020_PREFLIGHT: funções obrigatórias ausentes.';
  end if;

  if exists (
    select 1 from supabase_migrations.schema_migrations where version = '0020'
  ) then
    raise exception 'M0020_PREFLIGHT: migration 0020 já aplicada.';
  end if;
end
$$;

select 'M0020_PREFLIGHT_OK' as result, now() as checked_at;
