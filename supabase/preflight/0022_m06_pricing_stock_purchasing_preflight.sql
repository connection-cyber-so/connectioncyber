do $$ begin
 if current_setting('server_version_num')::integer < 150000 then raise exception 'PostgreSQL 15+ obrigatório'; end if;
 if to_regclass('public.erp_catalog_items') is null or to_regclass('public.erp_parties') is null or to_regclass('public.erp_establishments') is null then raise exception 'M02/M05 ausente'; end if;
 if to_regclass('public.erp_stock_movements') is not null then raise exception 'Objetos M06 já existem sem histórico 0022'; end if;
 if exists(select 1 from public.erp_permissions where key in('pricing.read','pricing.manage','stock.read','stock.manage','stock.count','purchasing.read','purchasing.manage','purchasing.receive') and category not in('Preços','Estoque','Compras')) then raise exception 'Colisão de permissões M06'; end if;
end $$;
select now() as checked_at,'M06_PREFLIGHT_OK' as result;
