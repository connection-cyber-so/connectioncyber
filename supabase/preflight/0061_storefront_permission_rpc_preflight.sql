-- Preflight 0061 (somente leitura)
-- Espera: has_permission existe; função nova ainda não existe; tabela tenants tem coluna ativo.
select
  to_regprocedure('erp_security.has_permission(uuid,text)') is not null as has_permission_existe,
  to_regprocedure('public.storefront_has_permission(uuid,text)') is null as funcao_nova_livre,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='tenants' and column_name='ativo') as tenants_ativo_existe;
