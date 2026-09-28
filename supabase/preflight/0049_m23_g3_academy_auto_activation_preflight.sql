-- Read-only; 0049 prerequisites: 0048 applied and the capacity filter still absent.
do $$
begin
  if to_regclass('public.academy_tenant_courses') is null
     or to_regprocedure('public.academy_sync_links(uuid)') is null then
    raise exception 'M23_G3_PREFLIGHT: catalogo global (migration 0048) ausente.';
  end if;
  if exists(select 1 from pg_trigger where not tgisinternal
            and tgname in ('trg_academy_capabilities_sync','trg_academy_capability_exceptions_sync')) then
    raise exception 'M23_G3_PREFLIGHT: gatilhos de capacidade ja existem; migration 0049 ja aplicada.';
  end if;
  if to_regprocedure('public.academy_sync_capability_trg()') is not null then
    raise exception 'M23_G3_PREFLIGHT: funcao do gatilho de capacidade ja existe; migration 0049 ja aplicada.';
  end if;
  if exists(select 1 from supabase_migrations.schema_migrations where version = '0049') then
    raise exception 'M23_G3_PREFLIGHT: migration 0049 ja aplicada.';
  end if;
  if (select pg_get_functiondef('public.academy_sync_links(uuid)'::regprocedure) like '%academy_capability%') then
    raise exception 'M23_G3_PREFLIGHT: sincronia ja filtra capacidade; migration 0049 ja aplicada.';
  end if;
end $$;
select 'M23_G3_PREFLIGHT_OK' as result, now() as checked_at;
select count(*) as capacidades_academy from public.erp_tenant_capabilities where capability_key='academy.courses';
select count(*) as exceptions_academy from public.erp_tenant_capability_exceptions where capability_key='academy.courses';
select count(*) as vinculos_auto from public.academy_tenant_courses where origem='auto';
-- Heranca do hardening 0048: anon le o catalogo legado e nao a academia.
select has_table_privilege('anon','public.courses','select') as anon_courses_select,
       has_table_privilege('anon','public.academy_courses','select') as anon_academy_select;
