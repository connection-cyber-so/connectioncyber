do $$ begin
 if current_setting('server_version_num')::integer<150000 then raise exception 'PostgreSQL 15+ obrigatório'; end if;
 if to_regclass('public.erp_catalog_items') is null or to_regclass('public.erp_stock_movements') is null or to_regclass('public.erp_price_items') is null then raise exception 'M05/M06 ausente'; end if;
 if to_regclass('public.erp_sales') is not null then raise exception 'Objetos M07 já existem sem histórico 0023'; end if;
 if exists(select 1 from public.erp_permissions where key in('sales.read','sales.quote','sales.order','sales.complete','sales.return','sales.discount','payments.read','payments.manage','payments.refund','cash.read','cash.operate','cash.close','cash.adjust') and category not in('Vendas','Pagamentos','Caixa')) then raise exception 'Colisão de permissões M07'; end if;
end $$;
select now() checked_at,'M07_PREFLIGHT_OK' result;
