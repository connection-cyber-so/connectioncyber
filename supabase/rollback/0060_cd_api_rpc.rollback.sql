-- 0060 rollback. Só remove as RPCs; não toca nas funções internas nem nos dados.
begin;
drop function if exists public.cd_api_despachar_pedido(uuid, uuid);
drop function if exists public.cd_api_coletar_pedido(uuid, uuid);
drop function if exists public.cd_api_receber_transferencia(uuid, uuid);
drop function if exists public.cd_api_alocar_pedido(uuid, uuid, boolean);
drop function if exists public.cd_api_criar_pedido(uuid, uuid, text, jsonb);
drop function if exists public.cd_api_exigir(uuid, text, text);
commit;
