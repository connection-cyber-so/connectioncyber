do $$
declare v_schema text;
begin
  if current_setting('server_version_num')::integer<150000 then raise exception 'PostgreSQL 15+ obrigatório';end if;
  if to_regclass('public.erp_catalog_items')is null or to_regprocedure('erp_security.has_permission(uuid,text)')is null then raise exception 'M05/RBAC ausente';end if;
  if not exists(select 1 from pg_available_extensions where name='vector')then raise exception 'pgvector indisponível';end if;
  select n.nspname into v_schema from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='vector';
  if v_schema is not null and v_schema<>'extensions' and not exists(select 1 from pg_extension where extname='vector' and extrelocatable)then raise exception 'pgvector instalado em schema divergente e não relocável: %',v_schema;end if;
  if exists(select 1 from information_schema.columns where table_schema='public'and table_name='erp_catalog_items'and column_name in('embedding','fts'))
    and not exists(select 1 from supabase_migrations.schema_migrations where version='0027')then raise exception 'Objetos CTR já existem sem histórico 0027';end if;
end $$;
select now()checked_at,'CTR_0027_PREFLIGHT_OK'result;
