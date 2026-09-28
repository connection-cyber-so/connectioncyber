-- ConnectionCyber — M21-G2 (Trilha B, passo 1): `erp_prepare_pilot_provisioning_v1` (M18,
-- migration 0034) já concede automaticamente TODAS as permissões ativas ao papel 'owner' na
-- hora de provisionar um tenant novo — então Casa de Bolos e MEI (futuros) não precisam de
-- nada além deste gate. Só tenants provisionados ANTES de uma permissão existir ficam sem
-- ela (é o caso da Mania de Modas: provisionada no M18-G21, antes de `fiscal.item.manage`
-- do M20-G1 e `establishments.manage` do M21-G1 existirem). Isto preenche essa lacuna
-- retroativamente, pra qualquer tenant e qualquer permissão — não só as duas de hoje.
begin;

insert into public.erp_role_permissions(tenant_id,role_id,permission_id)
select r.tenant_id, r.id, p.id
from public.erp_roles r
cross join public.erp_permissions p
where r.key = 'owner' and r.is_system and p.active
on conflict (tenant_id,role_id,permission_id) do nothing;

commit;
