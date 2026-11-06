-- 0055 rollback. SÓ para ambiente local ou staging com tabelas vazias.
-- Em ambiente com dado, NÃO rodar: use forward-fix (ver apps/portal/README.md).
-- Aborta se qualquer tabela tiver linha. Tudo em uma transação com ON_ERROR_STOP:
-- se a checagem falhar, nenhum DROP é executado.
\set ON_ERROR_STOP on
begin;

do $$
begin
  if exists (select 1 from public.saldos) or exists (select 1 from public.enderecos)
     or exists (select 1 from public.locais) then
    raise exception 'rollback 0055 abortado: locais, enderecos ou saldos não estão vazias';
  end if;
end $$;

drop trigger if exists trg_saldos_updated_at on public.saldos;
drop trigger if exists trg_enderecos_updated_at on public.enderecos;
drop trigger if exists trg_locais_updated_at on public.locais;
drop trigger if exists trg_enderecos_valida_tipo_local on public.enderecos;

drop table if exists public.saldos;
drop table if exists public.enderecos;
drop table if exists public.locais;

drop function if exists public.enderecos_valida_tipo_local();
drop function if exists public.cd_set_updated_at();

commit;
