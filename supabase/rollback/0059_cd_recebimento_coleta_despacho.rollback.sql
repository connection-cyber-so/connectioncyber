-- 0059 rollback. SÓ sem movimentação de transferências ou pedidos coletados/despachados.
\set ON_ERROR_STOP on
begin;

do $$
begin
  if exists (select 1 from public.transferencias where status = 'recebida')
     or exists (select 1 from public.pedidos_cd where status in ('coletado', 'despachado')) then
    raise exception 'rollback 0059 abortado: há movimentação recebida, coletada ou despachada; use forward-fix';
  end if;
end $$;

drop function if exists public.cd_receber_transferencia(uuid, uuid);
drop function if exists public.cd_coletar_pedido(uuid, uuid);
drop function if exists public.cd_despachar_pedido(uuid, uuid);

commit;
