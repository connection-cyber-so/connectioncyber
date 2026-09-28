begin;set local role postgres;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions,pgtap;select plan(45);

select ok(to_regprocedure(signature) is not null,format('%s exists',signature))
from unnest(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'
]) signature;

select ok(p.prosecdef,format('%s security definer',p.proname))
from pg_proc p where p.oid=any(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'::regprocedure
]) order by p.proname;

select ok(exists(select 1 from unnest(p.proconfig) c where c like 'search_path=%' and c not like '%public%'),format('%s has empty search path',p.proname))
from pg_proc p where p.oid=any(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)'::regprocedure,
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'::regprocedure
]) order by p.proname;

select ok(not has_function_privilege('anon',signature,'EXECUTE'),format('anon cannot execute %s',signature))
from unnest(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'
]) signature;

select ok(has_function_privilege('authenticated',signature,'EXECUTE'),format('authenticated executes %s',signature))
from unnest(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'
]) signature;

select is((select count(*)::integer from public.erp_permissions where key='establishments.manage'),1,'permissão establishments.manage existe');

select ok(
  pg_get_constraintdef((select oid from pg_constraint where conname='erp_command_receipts_command_type_check'))
  ~ all(array[
    'party\.create','catalog\.item\.create','inventory\.receive','cash\.open','sale\.complete',
    'finance\.receivable\.settle','cash\.close','party\.document\.add','party\.contact\.add',
    'party\.address\.add','catalog\.item\.fiscal\.set','catalog\.item\.commercial\.set','establishment\.vertical\.set'
  ]),
  'constraint de tipo de comando cobre os 13 tipos (7 antigos + 6 novos)'
);

select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='erp_establishments' and policyname='erp_establishments_update_staff_or_manager'),'policy de update em erp_establishments existe (RLS defensiva)');

select ok(pg_get_functiondef(signature::regprocedure) like '%erp_require_command_access_v1%',format('%s checks access',signature))
from unnest(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'
]) signature;

select ok(pg_get_functiondef(signature::regprocedure) like '%erp_claim_command_v1%',format('%s claims receipt',signature))
from unnest(array[
  'public.erp_command_add_party_document_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_contact_v1(uuid,text,text,jsonb)',
  'public.erp_command_add_party_address_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_fiscal_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_item_commercial_data_v1(uuid,text,text,jsonb)',
  'public.erp_command_set_establishment_vertical_v1(uuid,text,text,jsonb)'
]) signature;

select * from finish();
rollback;
