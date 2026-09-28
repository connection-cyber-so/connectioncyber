-- M23-G3 post-apply verification (read-only): run after applying 0049.
select pg_get_functiondef('public.academy_sync_links(uuid)'::regprocedure) like '%academy_capability(t.id)%' as sync_filtra_capacidade;
select tgname,tgenabled from pg_trigger where not tgisinternal
 and tgname in ('trg_academy_capabilities_sync','trg_academy_capability_exceptions_sync') order by tgname;
select pg_get_triggerdef(oid) as definicao from pg_trigger where not tgisinternal
 and tgname in ('trg_academy_capabilities_sync','trg_academy_capability_exceptions_sync') order by tgname;
select to_regprocedure('public.academy_sync_capability_trg()') as funcao_gatilho,
       has_function_privilege('anon','public.academy_sync_capability_trg()','execute') as anon_must_be_false,
       has_function_privilege('authenticated','public.academy_sync_capability_trg()','execute') as authenticated_must_be_true;
select count(*) as gatilhos_0048_intactos from pg_trigger where not tgisinternal
 and tgname in ('trg_academy_courses_sync','trg_tenant_modules_academy_sync',
                'trg_tenants_academy_sync_insert','trg_tenants_academy_sync_vertical');
select has_table_privilege('anon','public.courses','select') as anon_courses_select,
       has_table_privilege('anon','public.academy_courses','select') as anon_academy_select;
select ten.nome as tenant,t.course_id,t.origem,t.ativo from public.academy_tenant_courses t
 join public.tenants ten on ten.id=t.tenant_id order by ten.nome,t.course_id;
-- Marcador final: a API remota (db query) devolve apenas o ultimo result set com linhas.
select 'M23_G3_POST_APPLY_OK::academy_capability_sync' as marcador
 where exists(select 1 from pg_trigger where not tgisinternal and tgname='trg_academy_capabilities_sync')
   and exists(select 1 from pg_trigger where not tgisinternal and tgname='trg_academy_capability_exceptions_sync')
   and (select pg_get_functiondef('public.academy_sync_links(uuid)'::regprocedure) like '%academy_capability%');
