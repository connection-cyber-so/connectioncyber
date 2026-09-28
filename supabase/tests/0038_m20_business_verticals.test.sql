begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions,pgtap;
select plan(20);

insert into public.tenants(nome,slug,vertical) values ('M20 G2 Synthetic','m20-g2-synthetic','teste') on conflict (slug) do nothing;
insert into public.erp_establishments(tenant_id,code,trade_name) values (
  (select id from public.tenants where slug='m20-g2-synthetic'),'HQ','Estabelecimento Sintetico G2'
) on conflict (tenant_id,code) do nothing;

select ok(to_regclass('public.erp_business_verticals') is not null,'tabela erp_business_verticals existe');
select ok(to_regclass('public.erp_vertical_attribute_requirements') is not null,'tabela erp_vertical_attribute_requirements existe');

select ok(c.relrowsecurity,format('RLS ativo em %s',c.relname))
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname=any(array['erp_business_verticals','erp_vertical_attribute_requirements'])
order by c.relname;

select ok(not has_table_privilege('anon','public.erp_business_verticals','SELECT'),'anon não lê verticais');
select ok(not has_table_privilege('anon','public.erp_vertical_attribute_requirements','SELECT'),'anon não lê requisitos de atributo');
select ok(has_table_privilege('authenticated','public.erp_business_verticals','SELECT'),'authenticated lê verticais (catálogo global)');
select ok(has_table_privilege('authenticated','public.erp_vertical_attribute_requirements','SELECT'),'authenticated lê requisitos de atributo');
select ok(not has_table_privilege('authenticated','public.erp_business_verticals','INSERT'),'authenticated não gerencia o catálogo global de verticais');
select ok(not has_table_privilege('authenticated','public.erp_vertical_attribute_requirements','INSERT'),'authenticated não gerencia requisitos de atributo');

select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.erp_vertical_attribute_requirements'::regclass and contype='f' and confrelid='public.erp_business_verticals'::regclass
),'FK requisito -> vertical existe');
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.erp_business_verticals'::regclass and contype='f' and confrelid='public.erp_segment_profiles'::regclass
),'FK vertical -> perfil de segmento (M16) existe');
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.erp_vertical_attribute_requirements'::regclass and contype='u'
),'constraint unique (vertical_code,attribute_code) existe');

select ok(exists(
  select 1 from information_schema.columns
  where table_schema='public' and table_name='erp_establishments' and column_name='vertical_code'
),'coluna erp_establishments.vertical_code existe');
select ok(exists(
  select 1 from pg_constraint
  where conrelid='public.erp_establishments'::regclass and contype='f' and confrelid='public.erp_business_verticals'::regclass
),'FK estabelecimento -> vertical existe');

select ok(
  (select array_agg(code order by code) from public.erp_business_verticals)
  = (select array_agg(v order by v) from unnest(array[
      'moda','oficina','restaurante','papelaria','material_construcao','celular_multi_cnpj',
      'adega','casa_de_bolos','loja_variedades','cabeleireiro_barbeiro','perfumaria_cosmetico',
      'loja_calcados','servicos_mei_pf','servicos_informatica'
    ]) as v),
  'os 14 códigos de vertical confirmados no G0 existem, e só eles'
);

select ok(exists(
  select 1 from public.erp_vertical_attribute_requirements
  where vertical_code='casa_de_bolos' and attribute_code='validade_dias' and required and data_type='number'
),'casa de bolos exige validade_dias (number, obrigatório)');
select is((select count(*)::integer from public.erp_vertical_attribute_requirements where vertical_code='adega'),2,'adega tem dois atributos exigidos (teor alcoólico + volume)');

insert into public.erp_business_verticals(code,name) values ('m20_g2_synthetic','Vertical Sintetica G2');
insert into public.erp_vertical_attribute_requirements(vertical_code,attribute_code,attribute_name) values ('m20_g2_synthetic','campo_teste','Campo Teste');
delete from public.erp_business_verticals where code='m20_g2_synthetic';
select ok(not exists(select 1 from public.erp_vertical_attribute_requirements where vertical_code='m20_g2_synthetic'),'cascade remove requisitos ao apagar a vertical');

update public.erp_establishments set vertical_code='moda'
where tenant_id=(select id from public.tenants where slug='m20-g2-synthetic') and code='HQ';
select ok(exists(
  select 1 from public.erp_establishments where tenant_id=(select id from public.tenants where slug='m20-g2-synthetic') and code='HQ' and vertical_code='moda'
),'estabelecimento assume vertical existente com sucesso');

select * from finish();
rollback;
