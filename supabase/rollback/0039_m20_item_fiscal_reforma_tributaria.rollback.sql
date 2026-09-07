do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0039' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0039 para continuar.';
  end if;
end $$;
begin;
alter table public.erp_item_fiscal_data drop column if exists cst_ibs_cbs;
alter table public.erp_item_fiscal_data drop column if exists cclass_trib;
commit;
