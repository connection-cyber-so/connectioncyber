do $$ begin
  if current_setting('app.rollback_confirmation',true) <> 'ROLLBACK_0041' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0041 para continuar.';
  end if;
end $$;
begin;

-- Reverte exatamente o que 0041 realmente muda hoje: as permissões criadas depois do
-- provisionamento da Mania de Modas (M18-G21, migration 0034) e que por isso não tinham
-- sido concedidas ao papel 'owner' dela automaticamente. Não mexe em nenhuma concessão
-- que já existia antes deste gate (ex.: parties.manage/catalog.manage, do M05).
delete from public.erp_role_permissions rp
using public.erp_roles r, public.erp_permissions p
where rp.tenant_id = r.tenant_id and rp.role_id = r.id and rp.permission_id = p.id
  and r.key = 'owner' and r.is_system
  and p.key in ('fiscal.item.read','fiscal.item.manage','establishments.manage');

commit;
