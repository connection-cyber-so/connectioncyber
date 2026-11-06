-- 0060_cd_api_rpc.sql
-- Data: 2026-11-06
-- Origem: M54-G6 (camada de API do CD). RPCs que a interface chama, no lugar das funções internas
--   (que continuam só para service_role).
-- Regras de acesso (fail-closed, por tenant):
--   - usuário autenticado (auth.uid() não nulo);
--   - permissão no tenant via erp_security.has_permission (membership ativa + papel + permissão);
--   - capacidade ativa no tenant (cd.armazenagem ou cd.expedicao), dentro do período.
--   criar pedido: sales.order + cd.armazenagem
--   alocar/aprovar, receber transferência: stock.manage + cd.armazenagem
--   coletar, despachar: stock.manage + cd.expedicao
-- Leitura de pedidos, transferências e saldos continua pela RLS (SELECT) já existente.
-- Fora de escopo: interface, dados FICTICIO (ficam nos testes), catálogo de produtos (produto_id sem FK).
-- Reversão: supabase/rollback/0060_cd_api_rpc.rollback.sql

-- Checagem central: permissão + capacidade no tenant
create or replace function public.cd_api_exigir(p_tenant_id uuid, p_permission text, p_capability text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'não autenticado' using errcode = '42501';
  end if;
  if p_tenant_id is null then
    raise exception 'tenant obrigatório' using errcode = '42501';
  end if;
  if not erp_security.has_permission(p_tenant_id, p_permission) then
    raise exception 'sem permissão % no tenant', p_permission using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.erp_tenant_capabilities c
    where c.tenant_id = p_tenant_id
      and c.capability_key = p_capability
      and c.status in ('trial', 'active')
      and (c.starts_at is null or c.starts_at <= now())
      and (c.ends_at is null or c.ends_at > now())
  ) then
    raise exception 'capacidade % inativa no tenant', p_capability using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.cd_api_exigir(uuid, text, text) from public, anon, authenticated;

-- Criar pedido do CD (com itens)
create or replace function public.cd_api_criar_pedido(
  p_tenant_id uuid,
  p_local_id uuid,
  p_canal text,
  p_itens jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id    uuid := gen_random_uuid();
  v_item  jsonb;
  v_qtd   integer;
  v_preco numeric(12,2);
  v_n     integer := 0;
begin
  perform public.cd_api_exigir(p_tenant_id, 'sales.order', 'cd.armazenagem');

  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'itens obrigatórios' using errcode = '22023';
  end if;

  insert into public.pedidos_cd (id, tenant_id, local_id, canal)
  values (v_id, p_tenant_id, p_local_id, p_canal);

  for v_item in select value from jsonb_array_elements(p_itens) as t(value) loop
    v_qtd := (v_item->>'qtd')::integer;
    v_preco := (v_item->>'preco_unit')::numeric(12,2);
    if v_qtd is null or v_qtd <= 0 or v_preco is null or v_preco < 0 or (v_item->>'produto_id') is null then
      raise exception 'item inválido' using errcode = '22023';
    end if;
    insert into public.pedidos_cd_itens (tenant_id, pedido_cd_id, produto_id, qtd, preco_unit)
    values (p_tenant_id, v_id, (v_item->>'produto_id')::uuid, v_qtd, v_preco);
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object('pedido_id', v_id, 'status', 'aguardando_aprovacao', 'itens', v_n);
end;
$$;

-- Alocar (ou aprovar acima do limite)
create or replace function public.cd_api_alocar_pedido(p_tenant_id uuid, p_pedido_id uuid, p_aprovado boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.cd_api_exigir(p_tenant_id, 'stock.manage', 'cd.armazenagem');
  return public.cd_alocar_pedido(p_tenant_id, p_pedido_id, coalesce(p_aprovado, false));
end;
$$;

-- Receber transferência loja → CD
create or replace function public.cd_api_receber_transferencia(p_tenant_id uuid, p_transferencia_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.cd_api_exigir(p_tenant_id, 'stock.manage', 'cd.armazenagem');
  return public.cd_receber_transferencia(p_tenant_id, p_transferencia_id);
end;
$$;

-- Coletar no CD
create or replace function public.cd_api_coletar_pedido(p_tenant_id uuid, p_pedido_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.cd_api_exigir(p_tenant_id, 'stock.manage', 'cd.expedicao');
  return public.cd_coletar_pedido(p_tenant_id, p_pedido_id);
end;
$$;

-- Despachar
create or replace function public.cd_api_despachar_pedido(p_tenant_id uuid, p_pedido_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.cd_api_exigir(p_tenant_id, 'stock.manage', 'cd.expedicao');
  return public.cd_despachar_pedido(p_tenant_id, p_pedido_id);
end;
$$;

revoke all on function public.cd_api_criar_pedido(uuid, uuid, text, jsonb) from public, anon;
revoke all on function public.cd_api_alocar_pedido(uuid, uuid, boolean) from public, anon;
revoke all on function public.cd_api_receber_transferencia(uuid, uuid) from public, anon;
revoke all on function public.cd_api_coletar_pedido(uuid, uuid) from public, anon;
revoke all on function public.cd_api_despachar_pedido(uuid, uuid) from public, anon;
grant execute on function public.cd_api_criar_pedido(uuid, uuid, text, jsonb) to authenticated;
grant execute on function public.cd_api_alocar_pedido(uuid, uuid, boolean) to authenticated;
grant execute on function public.cd_api_receber_transferencia(uuid, uuid) to authenticated;
grant execute on function public.cd_api_coletar_pedido(uuid, uuid) to authenticated;
grant execute on function public.cd_api_despachar_pedido(uuid, uuid) to authenticated;

comment on function public.cd_api_criar_pedido(uuid, uuid, text, jsonb) is 'M54-G6. RPC: cria pedido do CD. Exige sales.order + cd.armazenagem.';
comment on function public.cd_api_alocar_pedido(uuid, uuid, boolean) is 'M54-G6. RPC: aloca ou aprova pedido. Exige stock.manage + cd.armazenagem.';
comment on function public.cd_api_receber_transferencia(uuid, uuid) is 'M54-G6. RPC: recebe transferência loja → CD. Exige stock.manage + cd.armazenagem.';
comment on function public.cd_api_coletar_pedido(uuid, uuid) is 'M54-G6. RPC: coleta no CD. Exige stock.manage + cd.expedicao.';
comment on function public.cd_api_despachar_pedido(uuid, uuid) is 'M54-G6. RPC: despacha pedido. Exige stock.manage + cd.expedicao.';
