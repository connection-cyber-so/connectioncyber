do $$
begin
  if to_regprocedure('public.erp_prepare_pilot_provisioning_v1(jsonb)') is null
     or to_regprocedure('public.erp_record_pilot_auth_identity_v1(uuid,uuid)') is null
     or to_regprocedure('public.erp_finalize_pilot_identity_v1(uuid,uuid)') is null then
    raise exception 'M21_G6_PREFLIGHT: fundação M18 (migration 0034) incompleta.';
  end if;
  if to_regclass('public.erp_business_verticals') is null then
    raise exception 'M21_G6_PREFLIGHT: fundação M20-G2 (erp_business_verticals, migration 0038) incompleta.';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'erp_establishments' and column_name = 'vertical_code') then
    raise exception 'M21_G6_PREFLIGHT: erp_establishments.vertical_code (migration 0038) ausente.';
  end if;
  if to_regprocedure('public.erp_prepare_pilot_establishment_v1(text,jsonb)') is not null then
    raise exception 'M21_G6_PREFLIGHT: erp_prepare_pilot_establishment_v1 já existe.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0042') then
    raise exception 'M21_G6_PREFLIGHT: migration 0042 já aplicada.';
  end if;
end $$;
select 'M21_G6_PREFLIGHT_OK' as result, now() as checked_at;
