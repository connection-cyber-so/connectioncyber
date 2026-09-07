do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0037' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0037 para continuar.';
  end if;
end $$;
begin;
drop table if exists public.erp_item_commercial_data;
drop table if exists public.erp_item_fiscal_data;
delete from public.erp_permissions where key in ('fiscal.item.read','fiscal.item.manage');
commit;
