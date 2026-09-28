begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(9);

select throws_ok($$insert into public.erp_business_verticals(code,name) values ('MODA2','Invalido')$$,'23514');
select throws_ok($$insert into public.erp_vertical_attribute_requirements(vertical_code,attribute_code,attribute_name,data_type) values ('moda','campo_invalido','Campo Invalido','currency')$$,'23514');
select throws_ok($$insert into public.erp_vertical_attribute_requirements(vertical_code,attribute_code,attribute_name) values ('moda','tamanho','Duplicado')$$,'23505');
select throws_ok($$insert into public.erp_vertical_attribute_requirements(vertical_code,attribute_code,attribute_name) values ('vertical_inexistente','campo','Campo')$$,'23503');
select throws_ok($$insert into public.erp_business_verticals(code,name,segment_profile_key) values ('m20_g2_fk_test','Teste FK','perfil_inexistente')$$,'23503');
select throws_ok($$update public.erp_establishments set vertical_code='vertical_inexistente' where tenant_id=(select id from public.tenants where slug='m20-g2-synthetic') and code='HQ'$$,'23503');
select ok(not has_table_privilege('anon','public.erp_business_verticals','INSERT'),'anon não pode inserir vertical, nem forjando código');
select ok(not has_table_privilege('anon','public.erp_vertical_attribute_requirements','INSERT'),'anon não pode inserir requisito de atributo');
select throws_ok($$insert into public.erp_business_verticals(code,name) values ('moda','Duplicado')$$,'23505');

select * from finish();
rollback;
