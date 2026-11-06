-- 0057 rollback. SÓ com tabelas vazias.
-- Aborta se qualquer tabela da 0057 tiver linha. Tudo em uma transação com ON_ERROR_STOP.
\set ON_ERROR_STOP on
begin;

do $$
begin
  if exists (select 1 from public.reservas) or exists (select 1 from public.transferencia_itens)
     or exists (select 1 from public.transferencias) or exists (select 1 from public.pedidos_cd_itens)
     or exists (select 1 from public.pedidos_cd) or exists (select 1 from public.regras_saida)
     or exists (select 1 from public.cd_configuracoes) then
    raise exception 'rollback 0057 abortado: tabelas da 0057 não estão vazias';
  end if;
end $$;

drop table if exists public.reservas;
drop table if exists public.transferencia_itens;
drop table if exists public.transferencias;
drop table if exists public.pedidos_cd_itens;
drop table if exists public.pedidos_cd;
drop table if exists public.regras_saida;
drop table if exists public.cd_configuracoes;
drop function if exists public.cd_valida_tipos_locais();

commit;
