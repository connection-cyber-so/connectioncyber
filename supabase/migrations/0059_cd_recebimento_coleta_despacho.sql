-- 0059_cd_recebimento_coleta_despacho.sql
-- Data: 2026-11-06
-- Origem: M54-G5. Recebimento de transferência loja → CD, coleta no CD e despacho do pedido.
-- Regras (aprovadas em 06/11/2026):
--   - recebimento: tira da loja (qtd e reservado) e põe no CD (armazenagem), e a reserva do pedido passa da loja para o CD;
--   - coleta no CD: pedido com saída pelo CD só é coletado depois que todas as transferências dele foram recebidas;
--     a baixa do CD acontece na coleta (saldo e reserva consumidos);
--   - despacho: pedido sem CD (balcão, shopee) dá baixa na loja no despacho; pedido com CD exige coleta antes;
--   - nenhuma função mexe em saldo além do necessário: qtd e reservado sempre juntos.
-- Escrita só por funções security definer, execute só para service_role.
-- Fora de escopo: dados FICTICIO (ficam nos testes), catálogo de produtos (produto_id sem FK), API pública.
-- Reversão: supabase/rollback/0059_cd_recebimento_coleta_despacho.rollback.sql (só sem movimentação).

-- Recebimento: move a quantidade transferida da loja para o CD
create or replace function public.cd_receber_transferencia(p_tenant_id uuid, p_transferencia_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_t       public.transferencias%rowtype;
  v_item    record;
  v_res     record;
  v_end_cd  uuid;
  v_falta   integer;
  v_pega    integer;
begin
  select * into v_t from public.transferencias
  where tenant_id = p_tenant_id and id = p_transferencia_id
  for update;
  if not found then
    raise exception 'transferência não encontrada no tenant';
  end if;
  if v_t.status not in ('pendente', 'despachada') then
    raise exception 'transferência não recebível (status %)', v_t.status;
  end if;
  if v_t.pedido_cd_id is null then
    raise exception 'transferência sem pedido vinculado';
  end if;

  select e.id into v_end_cd from public.enderecos e
  where e.tenant_id = p_tenant_id and e.local_id = v_t.destino_local_id and e.tipo_uso = 'armazenagem'
  order by e.id limit 1;
  if v_end_cd is null then
    raise exception 'CD destino sem endereço de armazenagem';
  end if;

  for v_item in
    select produto_id, qtd from public.transferencia_itens
    where tenant_id = p_tenant_id and transferencia_id = p_transferencia_id
    order by produto_id
  loop
    v_falta := v_item.qtd;

    for v_res in
      select r.id, r.qtd, r.endereco_id from public.reservas r
      where r.tenant_id = p_tenant_id
        and r.pedido_cd_id = v_t.pedido_cd_id
        and r.produto_id = v_item.produto_id
        and r.status = 'ativa'
        and r.endereco_id in (select e.id from public.enderecos e
                              where e.tenant_id = p_tenant_id and e.local_id = v_t.origem_local_id)
      order by r.id
      for update
    loop
      exit when v_falta = 0;
      if v_res.qtd <= v_falta then
        update public.reservas set status = 'consumida' where tenant_id = p_tenant_id and id = v_res.id;
        v_pega := v_res.qtd;
      else
        update public.reservas set qtd = qtd - v_falta where tenant_id = p_tenant_id and id = v_res.id;
        insert into public.reservas (tenant_id, pedido_cd_id, produto_id, endereco_id, qtd, status)
        values (p_tenant_id, v_t.pedido_cd_id, v_item.produto_id, v_res.endereco_id, v_falta, 'consumida');
        v_pega := v_falta;
      end if;

      -- baixa na loja (qtd e reservado juntos)
      update public.saldos set qtd = qtd - v_pega, reservado = reservado - v_pega
      where tenant_id = p_tenant_id and produto_id = v_item.produto_id and endereco_id = v_res.endereco_id;

      -- entrada no CD
      insert into public.saldos (tenant_id, produto_id, endereco_id, qtd, reservado)
      values (p_tenant_id, v_item.produto_id, v_end_cd, v_pega, 0)
      on conflict (tenant_id, produto_id, endereco_id)
      do update set qtd = public.saldos.qtd + excluded.qtd;

      -- reserva do pedido passa para o CD
      update public.saldos set reservado = reservado + v_pega
      where tenant_id = p_tenant_id and produto_id = v_item.produto_id and endereco_id = v_end_cd;
      insert into public.reservas (tenant_id, pedido_cd_id, produto_id, endereco_id, qtd)
      values (p_tenant_id, v_t.pedido_cd_id, v_item.produto_id, v_end_cd, v_pega);

      v_falta := v_falta - v_pega;
    end loop;

    if v_falta > 0 then
      raise exception 'reserva na loja insuficiente para transferir: produto % faltam %', v_item.produto_id, v_falta;
    end if;
  end loop;

  update public.transferencias set status = 'recebida', recebido_em = now()
  where tenant_id = p_tenant_id and id = p_transferencia_id;

  return jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'recebida');
end;
$$;

-- Coleta no CD: só com todas as transferências do pedido recebidas; baixa do CD
create or replace function public.cd_coletar_pedido(p_tenant_id uuid, p_pedido_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_p    public.pedidos_cd%rowtype;
  v_r    record;
  v_n    integer := 0;
begin
  select * into v_p from public.pedidos_cd
  where tenant_id = p_tenant_id and id = p_pedido_id
  for update;
  if not found then
    raise exception 'pedido não encontrado no tenant';
  end if;
  if v_p.status <> 'autorizada' then
    raise exception 'pedido não pode ser coletado (status %)', v_p.status;
  end if;
  if exists (select 1 from public.transferencias t
             where t.tenant_id = p_tenant_id and t.pedido_cd_id = p_pedido_id
               and t.status in ('pendente', 'despachada')) then
    raise exception 'há transferência não recebida para este pedido';
  end if;

  for v_r in
    select r.id, r.produto_id, r.endereco_id, r.qtd
    from public.reservas r
    join public.enderecos e on e.tenant_id = r.tenant_id and e.id = r.endereco_id
    join public.locais l on l.tenant_id = e.tenant_id and l.id = e.local_id
    where r.tenant_id = p_tenant_id and r.pedido_cd_id = p_pedido_id
      and r.status = 'ativa' and l.tipo = 'cd'
    order by r.id
    for update of r
  loop
    update public.saldos set qtd = qtd - v_r.qtd, reservado = reservado - v_r.qtd
    where tenant_id = p_tenant_id and produto_id = v_r.produto_id and endereco_id = v_r.endereco_id;
    update public.reservas set status = 'consumida' where tenant_id = p_tenant_id and id = v_r.id;
    v_n := v_n + 1;
  end loop;

  update public.pedidos_cd set status = 'coletado', coletado_em = now()
  where tenant_id = p_tenant_id and id = p_pedido_id;

  return jsonb_build_object('pedido_id', p_pedido_id, 'status', 'coletado', 'reservas_baixadas', v_n);
end;
$$;

-- Despacho: pedido sem CD dá baixa na loja; pedido com CD exige coleta antes
create or replace function public.cd_despachar_pedido(p_tenant_id uuid, p_pedido_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_p    public.pedidos_cd%rowtype;
  v_r    record;
  v_n    integer := 0;
begin
  select * into v_p from public.pedidos_cd
  where tenant_id = p_tenant_id and id = p_pedido_id
  for update;
  if not found then
    raise exception 'pedido não encontrado no tenant';
  end if;
  if v_p.status not in ('autorizada', 'coletado') then
    raise exception 'pedido não pode ser despachado (status %)', v_p.status;
  end if;
  if v_p.status = 'autorizada' and exists (
       select 1 from public.reservas r
       join public.enderecos e on e.tenant_id = r.tenant_id and e.id = r.endereco_id
       join public.locais l on l.tenant_id = e.tenant_id and l.id = e.local_id
       where r.tenant_id = p_tenant_id and r.pedido_cd_id = p_pedido_id
         and r.status = 'ativa' and l.tipo = 'cd') then
    raise exception 'pedido com saída pelo CD exige coleta antes do despacho';
  end if;
  if exists (select 1 from public.transferencias t
             where t.tenant_id = p_tenant_id and t.pedido_cd_id = p_pedido_id
               and t.status in ('pendente', 'despachada')) then
    raise exception 'há transferência não recebida para este pedido';
  end if;

  for v_r in
    select r.id, r.produto_id, r.endereco_id, r.qtd from public.reservas r
    where r.tenant_id = p_tenant_id and r.pedido_cd_id = p_pedido_id and r.status = 'ativa'
    order by r.id
    for update
  loop
    update public.saldos set qtd = qtd - v_r.qtd, reservado = reservado - v_r.qtd
    where tenant_id = p_tenant_id and produto_id = v_r.produto_id and endereco_id = v_r.endereco_id;
    update public.reservas set status = 'consumida' where tenant_id = p_tenant_id and id = v_r.id;
    v_n := v_n + 1;
  end loop;

  update public.pedidos_cd set status = 'despachado', despachado_em = now()
  where tenant_id = p_tenant_id and id = p_pedido_id;

  return jsonb_build_object('pedido_id', p_pedido_id, 'status', 'despachado', 'reservas_baixadas', v_n);
end;
$$;

revoke all on function public.cd_receber_transferencia(uuid, uuid) from public, anon, authenticated;
revoke all on function public.cd_coletar_pedido(uuid, uuid) from public, anon, authenticated;
revoke all on function public.cd_despachar_pedido(uuid, uuid) from public, anon, authenticated;
grant execute on function public.cd_receber_transferencia(uuid, uuid) to service_role;
grant execute on function public.cd_coletar_pedido(uuid, uuid) to service_role;
grant execute on function public.cd_despachar_pedido(uuid, uuid) to service_role;

comment on function public.cd_receber_transferencia(uuid, uuid) is 'M54-G5. Recebe transferência loja → CD: move qtd e reserva da loja para o CD. Só service_role.';
comment on function public.cd_coletar_pedido(uuid, uuid) is 'M54-G5. Coleta no CD com baixa de saldo e reserva. Exige transferências recebidas. Só service_role.';
comment on function public.cd_despachar_pedido(uuid, uuid) is 'M54-G5. Despacho: baixa na loja (sem CD) ou após coleta. Só service_role.';
