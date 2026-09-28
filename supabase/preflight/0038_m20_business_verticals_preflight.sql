do $$
begin
  if to_regclass('public.erp_segment_profiles') is null
     or to_regclass('public.erp_establishments') is null
     or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'M20_PREFLIGHT: fundações M02/M16 incompletas.';
  end if;
  if to_regclass('public.erp_business_verticals') is not null
     or to_regclass('public.erp_vertical_attribute_requirements') is not null then
    raise exception 'M20_PREFLIGHT: objetos M20-G2 já existem.';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='erp_establishments' and column_name='vertical_code'
  ) then
    raise exception 'M20_PREFLIGHT: coluna erp_establishments.vertical_code já existe.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version='0038') then
    raise exception 'M20_PREFLIGHT: migration 0038 já aplicada.';
  end if;
end $$;
select 'M20_G2_PREFLIGHT_OK' as result, now() as checked_at;
