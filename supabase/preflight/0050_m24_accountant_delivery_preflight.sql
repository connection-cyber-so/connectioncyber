-- Read-only; 0050 prerequisites: 0049 applied, accountant delivery objects still absent.
do $$
begin
  if to_regprocedure('erp_security.has_permission(uuid,text)') is null then
    raise exception 'M24_PREFLIGHT: helper erp_security.has_permission(uuid,text) ausente (base M02/M16).';
  end if;
  if to_regclass('public.erp_accountant_packages') is not null
     or to_regclass('public.erp_accountant_package_files') is not null
     or to_regclass('public.erp_accountant_delivery_events') is not null then
    raise exception 'M24_PREFLIGHT: tabelas de pacote do contador ja existem; migration 0050 ja aplicada.';
  end if;
  if exists(select 1 from storage.buckets where id = 'fiscal-deliveries') then
    raise exception 'M24_PREFLIGHT: bucket fiscal-deliveries ja existe; migration 0050 ja aplicada.';
  end if;
  if exists(select 1 from public.roles where nome = 'contador') then
    raise exception 'M24_PREFLIGHT: papel contador ja existe; migration 0050 ja aplicada.';
  end if;
  if exists(select 1 from supabase_migrations.schema_migrations where version = '0050') then
    raise exception 'M24_PREFLIGHT: migration 0050 ja aplicada.';
  end if;
end $$;
select count(*) as historico_ate_0049 from supabase_migrations.schema_migrations
 where version between '0001' and '0049';
-- Marcador por ultimo: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M24_PREFLIGHT_OK' as result, now() as checked_at;
