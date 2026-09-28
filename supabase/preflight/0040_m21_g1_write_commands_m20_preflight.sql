do $$
begin
  if to_regclass('public.erp_command_receipts') is null then
    raise exception 'M21_PREFLIGHT: fundação M17 (erp_command_receipts) incompleta.';
  end if;
  if to_regclass('public.erp_party_documents') is null
    or to_regclass('public.erp_item_fiscal_data') is null
    or to_regclass('public.erp_establishments') is null then
    raise exception 'M21_PREFLIGHT: tabelas satélite do M05/M20 incompletas.';
  end if;
  if to_regprocedure('public.erp_command_add_party_document_v1(uuid,text,text,jsonb)') is not null then
    raise exception 'M21_PREFLIGHT: comandos de escrita do M20 já existem.';
  end if;
  if exists (select 1 from public.erp_permissions where key = 'establishments.manage') then
    raise exception 'M21_PREFLIGHT: permissão establishments.manage já existe.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0040') then
    raise exception 'M21_PREFLIGHT: migration 0040 já aplicada.';
  end if;
end $$;
select 'M21_G1_PREFLIGHT_OK' as result, now() as checked_at;
