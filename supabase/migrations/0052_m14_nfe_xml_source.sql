-- ConnectionCyber - M14 lote real: fonte nfe_xml no ledger de importacao (0031).
-- Aditiva: estende o allowlist de source_type (check da tabela + RPC de registro)
-- para suportar a carga real dos XMLs de NF-e do SICNET. Nao altera RLS, grants
-- nem as demais funcoes do ledger.
begin;

alter table public.erp_import_manifests
  drop constraint if exists erp_import_manifests_source_type_check;
alter table public.erp_import_manifests
  add constraint erp_import_manifests_source_type_check
  check(source_type in('sqlserver_backup','sqlserver_readonly','csv_export','json_export','nfe_xml'));

create or replace function public.erp_register_import_manifest(p_tenant_id uuid,p_idempotency_key text,p_source_type text,p_source_sha256 text,p_schema_version text,p_captured_at timestamptz,p_metadata jsonb)returns uuid language plpgsql security definer set search_path=''as $$
declare v_existing record;v_id uuid;
begin
 if auth.role()<>'service_role'then raise exception 'broker only';end if;
 if length(btrim(p_idempotency_key))not between 16 and 200 or p_source_type not in('sqlserver_backup','sqlserver_readonly','csv_export','json_export','nfe_xml')or p_source_sha256!~'^[a-f0-9]{64}$'or p_schema_version!~'^legacy-[a-z0-9.-]+$'or p_captured_at is null or jsonb_typeof(p_metadata)<>'object'then raise exception 'invalid manifest';end if;
 if (p_metadata - array['source_system','source_version','record_count','export_format','notes_hash'])<>'{}'::jsonb or p_metadata::text~*'"(password|senha|secret|token|credential|private_key|service_role|certificate|certificado|pfx|p12|csc|connection_string|source_path)"[[:space:]]*:'or p_metadata::text~*'(postgres(ql)?://|server[[:space:]]*=|data source[[:space:]]*=|[a-z]:\\\\|/home/|/users/|begin [a-z ]*private key)'then raise exception 'secret, source path or unknown metadata forbidden';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_tenant_id::text||':manifest:'||btrim(p_idempotency_key),0));
 select id,source_type,source_sha256,schema_version,captured_at,metadata into v_existing from public.erp_import_manifests where tenant_id=p_tenant_id and idempotency_key=btrim(p_idempotency_key);
 if v_existing.id is not null then if v_existing.source_type<>p_source_type or v_existing.source_sha256<>p_source_sha256 or v_existing.schema_version<>p_schema_version or v_existing.captured_at<>p_captured_at or v_existing.metadata<>p_metadata then raise exception 'manifest idempotency conflict';end if;return v_existing.id;end if;
 insert into public.erp_import_manifests(tenant_id,idempotency_key,source_type,source_sha256,schema_version,captured_at,metadata)values(p_tenant_id,btrim(p_idempotency_key),p_source_type,p_source_sha256,p_schema_version,p_captured_at,p_metadata)returning id into v_id;return v_id;
end$$;

commit;
