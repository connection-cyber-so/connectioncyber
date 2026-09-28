-- Somente laboratório vazio. Em ambiente com uso, aplicar forward-fix.
begin;
do $$ begin if exists(select 1 from public.erp_food_tabs)or exists(select 1 from public.erp_table_sessions)or exists(select 1 from public.erp_kitchen_tickets)then raise exception 'Rollback recusado: há dados M10';end if;end $$;
drop function if exists public.erp_close_food_tab(uuid,uuid,integer,text),public.erp_open_table_session(uuid,uuid,integer,text);
drop table if exists public.erp_food_tab_splits,public.erp_food_fulfillments,public.erp_kitchen_ticket_items,public.erp_kitchen_tickets,public.erp_kitchen_stations,public.erp_recipe_yields,public.erp_food_order_item_modifiers,public.erp_modifiers,public.erp_modifier_groups,public.erp_food_order_items,public.erp_food_orders,public.erp_food_tab_events,public.erp_food_tab_guests,public.erp_food_tabs,public.erp_table_session_events,public.erp_table_sessions,public.erp_dining_tables,public.erp_dining_areas cascade;
delete from public.erp_permissions where key like 'food.%';
commit;
