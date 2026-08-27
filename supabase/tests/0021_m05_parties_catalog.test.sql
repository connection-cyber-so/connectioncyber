begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(44);

select ok(to_regclass(format('public.%I',table_name)) is not null,format('tabela %s existe',table_name)) from unnest(array[
  'erp_parties','erp_party_roles','erp_party_documents','erp_party_contacts','erp_party_addresses','erp_employees',
  'erp_units','erp_unit_conversions','erp_catalog_items','erp_item_variants','erp_item_identifiers','erp_attributes',
  'erp_attribute_values','erp_item_attribute_values','erp_item_compositions','erp_item_composition_lines'
]) as names(table_name);

select ok(c.relrowsecurity,format('RLS ativo em %s',c.relname))
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname=any(array[
  'erp_parties','erp_party_roles','erp_party_documents','erp_party_contacts','erp_party_addresses','erp_employees',
  'erp_units','erp_unit_conversions','erp_catalog_items','erp_item_variants','erp_item_identifiers','erp_attributes',
  'erp_attribute_values','erp_item_attribute_values','erp_item_compositions','erp_item_composition_lines'
]) order by c.relname;

select ok(not has_table_privilege('anon','public.erp_parties','SELECT'),'anon não lê pessoas');
select ok(not has_table_privilege('anon','public.erp_catalog_items','SELECT'),'anon não lê catálogo ERP');
select ok(has_table_privilege('authenticated','public.erp_parties','SELECT'),'authenticated possui grant filtrado por RLS');
select ok(has_table_privilege('authenticated','public.erp_catalog_items','SELECT'),'authenticated possui grant filtrado por RLS');
select ok(not has_table_privilege('authenticated','public.erp_parties','DELETE'),'cadastro usa exclusão lógica');
select ok(not has_table_privilege('authenticated','public.erp_catalog_items','DELETE'),'catálogo usa exclusão lógica');

select is((select count(*)::integer from public.erp_permissions where key in ('parties.read','parties.manage','catalog.read','catalog.manage')),4,'quatro permissões M05 existem');
select ok(exists(select 1 from pg_constraint where conname='erp_parties_tenant_id_unique'),'party possui chave composta tenant');
select ok(exists(select 1 from pg_constraint where conname='erp_catalog_items_tenant_id_unique'),'item possui chave composta tenant');
select ok(exists(select 1 from pg_constraint where conname='erp_units_tenant_id_unique'),'unidade possui chave composta tenant');
select ok(not has_function_privilege('anon','public.erp_create_party(uuid,text,text,text,text,text)','EXECUTE'),'anon não executa criação atômica');
select ok(has_function_privilege('authenticated','public.erp_create_party(uuid,text,text,text,text,text)','EXECUTE'),'authenticated usa criação atômica sob RLS');

select * from finish();
rollback;
