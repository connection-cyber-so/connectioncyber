do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0021' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0021 para continuar.';
  end if;
end $$;
begin;
drop function if exists public.erp_create_party(uuid,text,text,text,text,text);
drop table if exists public.erp_item_composition_lines;
drop table if exists public.erp_item_compositions;
drop table if exists public.erp_item_attribute_values;
drop table if exists public.erp_attribute_values;
drop table if exists public.erp_attributes;
drop table if exists public.erp_item_identifiers;
drop table if exists public.erp_item_variants;
drop table if exists public.erp_catalog_items;
drop table if exists public.erp_unit_conversions;
drop table if exists public.erp_units;
drop table if exists public.erp_employees;
drop table if exists public.erp_party_addresses;
drop table if exists public.erp_party_contacts;
drop table if exists public.erp_party_documents;
drop table if exists public.erp_party_roles;
drop table if exists public.erp_parties;
delete from public.erp_permissions where key in ('parties.read','parties.manage','catalog.read','catalog.manage');
commit;
