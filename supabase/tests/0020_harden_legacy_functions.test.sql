begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;

select plan(4);

select is(
  (select p.proconfig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'set_updated_at'),
  array['search_path=""'],
  'set_updated_at usa search_path vazio'
);
select ok(not has_function_privilege('anon', 'public.is_platform_staff()', 'EXECUTE'), 'anon não executa is_platform_staff');
select ok(has_function_privilege('authenticated', 'public.is_platform_staff()', 'EXECUTE'), 'authenticated executa is_platform_staff');
select ok(has_function_privilege('service_role', 'public.is_platform_staff()', 'EXECUTE'), 'service_role executa is_platform_staff');

select * from finish();
rollback;
