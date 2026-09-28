begin;
drop function if exists public.erp_ingest_fiscal_provider_event(uuid,text,text,text,text,timestamptz);
drop function if exists public.erp_transition_fiscal_document(uuid,uuid,text,text,text,jsonb,text);
drop function if exists public.erp_create_fiscal_document(uuid,uuid,uuid,uuid,text,jsonb,jsonb,timestamptz,text);
drop function if exists public.erp_reserve_fiscal_number(uuid,uuid,text,text,integer,text);
drop table if exists public.erp_fiscal_webhook_inbox,public.erp_certificate_refs,public.erp_fiscal_contingencies,public.erp_fiscal_xml_artifacts,public.erp_fiscal_events,public.erp_fiscal_transmissions,public.erp_fiscal_document_items,public.erp_fiscal_documents,public.erp_fiscal_number_reservations,public.erp_fiscal_series,public.erp_fiscal_schema_versions,public.erp_tax_rules,public.erp_tax_profiles,public.erp_tax_regimes cascade;
alter table public.erp_sales drop constraint if exists erp_sales_tenant_establishment_id_unique;
delete from public.erp_permissions where key in('fiscal.read','fiscal.issue','fiscal.cancel','fiscal.configure','fiscal.certificate.manage','fiscal.audit');
commit;
