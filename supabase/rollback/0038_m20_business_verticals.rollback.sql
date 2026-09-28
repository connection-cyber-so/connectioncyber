do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0038' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0038 para continuar.';
  end if;
end $$;
begin;
alter table public.erp_establishments drop column if exists vertical_code;
drop table if exists public.erp_vertical_attribute_requirements;
drop table if exists public.erp_business_verticals;
commit;
