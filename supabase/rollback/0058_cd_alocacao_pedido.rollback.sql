-- 0058 rollback. SÓ sem reservas, transferências ou pedidos vinculados ao tenant Nuvem.
\set ON_ERROR_STOP on
begin;

do $$
begin
  if exists (select 1 from public.reservas) or exists (select 1 from public.transferencias) then
    raise exception 'rollback 0058 abortado: há reservas ou transferências; use forward-fix';
  end if;
end $$;

drop function if exists public.cd_alocar_pedido(uuid, uuid, boolean);
delete from public.regras_saida where tenant_id = '00000000-0000-0000-0000-000000000001';
delete from public.cd_configuracoes where tenant_id = '00000000-0000-0000-0000-000000000001';

commit;
