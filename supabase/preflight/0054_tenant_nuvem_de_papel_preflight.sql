-- 0054 preflight: somente leitura. Esperado: todas as linhas com ok = true.
select 'tenant_id_livre' as check, not exists (select 1 from public.tenants where id = '00000000-0000-0000-0000-000000000001') as ok
union all select 'slug_livre', not exists (select 1 from public.tenants where slug = 'nuvemdepapel')
union all select 'vertical_papelaria_existe', exists (select 1 from public.erp_business_verticals where code = 'papelaria')
union all select 'dominio_livre', not exists (select 1 from public.tenant_domains where hostname = 'nuvemdepapel.com.br')
union all select 'capacidades_existem', (select count(*) from unnest(array['sales.pos','sales.orders','core.parties','core.catalog','core.pricing','procurement','inventory.stock','finance','migration','fiscal']) k where exists (select 1 from public.erp_capability_catalog c where c.key = k)) = 10;
