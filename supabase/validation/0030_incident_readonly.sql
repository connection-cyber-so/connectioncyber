select jsonb_build_object('rows',jsonb_build_object(
  'tax_regimes',(select count(*)from public.erp_tax_regimes),
  'tax_profiles',(select count(*)from public.erp_tax_profiles),
  'tax_rules',(select count(*)from public.erp_tax_rules),
  'schema_versions',(select count(*)from public.erp_fiscal_schema_versions),
  'series',(select count(*)from public.erp_fiscal_series),
  'reservations',(select count(*)from public.erp_fiscal_number_reservations),
  'documents',(select count(*)from public.erp_fiscal_documents),
  'items',(select count(*)from public.erp_fiscal_document_items),
  'transmissions',(select count(*)from public.erp_fiscal_transmissions),
  'events',(select count(*)from public.erp_fiscal_events),
  'artifacts',(select count(*)from public.erp_fiscal_xml_artifacts),
  'contingencies',(select count(*)from public.erp_fiscal_contingencies),
  'certificate_refs',(select count(*)from public.erp_certificate_refs),
  'webhooks',(select count(*)from public.erp_fiscal_webhook_inbox)
),'permissions',(select count(*)from public.erp_permissions where key in('fiscal.read','fiscal.issue','fiscal.cancel','fiscal.configure','fiscal.certificate.manage','fiscal.audit')),'rls_tables',(select count(*)from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'and c.relrowsecurity and c.relname=any(array['erp_tax_regimes','erp_tax_profiles','erp_tax_rules','erp_fiscal_schema_versions','erp_fiscal_series','erp_fiscal_number_reservations','erp_fiscal_documents','erp_fiscal_document_items','erp_fiscal_transmissions','erp_fiscal_events','erp_fiscal_xml_artifacts','erp_fiscal_contingencies','erp_certificate_refs','erp_fiscal_webhook_inbox'])))as m13_state;
