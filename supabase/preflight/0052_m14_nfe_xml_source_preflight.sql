-- Read-only; 0052 prerequisites: 0031 applied, nfe_xml not yet allowed.
do $$
begin
  if to_regclass('public.erp_import_manifests') is null then
    raise exception 'M14_0052_PREFLIGHT: migration 0031 (ledger de importacao) nao aplicada.';
  end if;
  if to_regprocedure('public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)') is null then
    raise exception 'M14_0052_PREFLIGHT: RPC erp_register_import_manifest ausente (0031).';
  end if;
  if exists(select 1 from supabase_migrations.schema_migrations where version = '0052') then
    raise exception 'M14_0052_PREFLIGHT: migration 0052 ja aplicada.';
  end if;
  if exists(select 1 from pg_constraint where conrelid = 'public.erp_import_manifests'::regclass
            and conname = 'erp_import_manifests_source_type_check'
            and pg_get_constraintdef(oid) like '%nfe_xml%') then
    raise exception 'M14_0052_PREFLIGHT: check de source_type ja inclui nfe_xml; 0052 ja aplicada.';
  end if;
  if exists(select 1 from pg_proc where proname = 'erp_register_import_manifest'
            and pg_get_functiondef(oid) like '%nfe_xml%') then
    raise exception 'M14_0052_PREFLIGHT: RPC de manifesto ja aceita nfe_xml; 0052 ja aplicada.';
  end if;
end $$;
select count(*) as historico_ate_0051 from supabase_migrations.schema_migrations
 where version in('0001','0002','0003','0004','0005','0006','0007','0008','0009','0010','0011','0012','0013','0014','0015','0016','0017','0018','0019','0020','0021','0022','0023','0024','0025','0026','0027','0028','0029','0030','0031','0032','0033','0034','0035','0036','0037','0038','0039','0040','0041','0042','0043','0044','0045','0046','0047','0048','0049','0050','0051');
select 'M14_0052_PREFLIGHT_OK' as marcador
 where to_regclass('public.erp_import_manifests') is not null
   and to_regprocedure('public.erp_register_import_manifest(uuid,text,text,text,text,timestamptz,jsonb)') is not null;
