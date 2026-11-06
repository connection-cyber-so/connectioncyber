-- 0058_cd_alocacao_pedido.sql
-- Data: 2026-11-06
-- Origem: M54-G4. Alocação ponta a ponta de um pedido do CD + configuração padrão da Nuvem.
-- Regras (aprovadas em 06/11/2026):
--   - limite automático 50 un. ou R$ 2.000: acima disso fica 'aguardando_aprovacao' e não reserva nada
--     até aprovação explícita (p_aprovado = true);
--   - com 'cd' nas regras de saída do canal, reserva primeiro no CD;
--   - falta no CD + política 'transferencia_automatica' + 'loja' nas regras: reserva a quantidade
--     na loja e gera transferência loja → CD ligada ao pedido;
--   - sem 'cd' nas regras (balcão, shopee): reserva direto na loja;
--   - sem estoque suficiente: a falta fica registrada no retorno, sem reserva fantasma.
-- Escrita de reserva/transferência só ocorre dentro desta função (security definer, só service_role).
-- Fora de escopo: recebimento da transferência, coleta e despacho (fases seguintes), dados FICTICIO (ficam nos testes).
-- Reversão: supabase/rollback/0058_cd_alocacao_pedido.rollback.sql (só sem pedidos alocados).

-- Configuração padrão da Nuvem de Papel (somente inserts, sem dado de cliente)
insert into public.cd_configuracoes (tenant_id)
values ('00000000-0000-0000-0000-000000000001')
on conflict (tenant_id) do nothing;

insert into public.regras_saida (tenant_id, canal, prioridade, local_tipo) values
  ('00000000-0000-0000-0000-000000000001', 'web', 1, 'cd'),
  ('00000000-0000-0000-0000-000000000001', 'web', 2, 'loja'),
  ('00000000-0000-0000-0000-000000000001', 'balcao', 1, 'loja'),
  ('00000000-0000-0000-0000-000000000001', 'shopee', 1, 'loja')
on conflict do nothing;

create or replace function public.cd_alocar_pedido(
  p_tenant_id uuid,
  p_pedido_id uuid,
  p_aprovado boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pedido        public.pedidos_cd%rowtype;
  v_cfg           public.cd_configuracoes%rowtype;
  v_item          record;
  v_end           record;
  v_falta         integer;
  v_pega          integer;
  v_efetivo       text;
  v_tem_cd        boolean;
  v_tem_loja      boolean;
  v_total_qtd     integer;
  v_total_valor   numeric(12,2);
  v_reservado_cd  integer := 0;
  v_transferido   integer := 0;
  v_falta_final   integer := 0;
  v_transf_id     uuid;
begin
  select * into v_pedido from public.pedidos_cd
  where tenant_id = p_tenant_id and id = p_pedido_id
  for update;
  if not found then
    raise exception 'pedido não encontrado no tenant';
  end if;
  if v_pedido.status <> 'aguardando_aprovacao' then
    raise exception 'pedido já alocado (status %)', v_pedido.status;
  end if;

  select * into v_cfg from public.cd_configuracoes where tenant_id = p_tenant_id;
  if not found then
    raise exception 'tenant sem cd_configuracoes';
  end if;

  select coalesce(sum(qtd), 0), coalesce(sum(qtd * preco_unit), 0)
    into v_total_qtd, v_total_valor
  from public.pedidos_cd_itens
  where tenant_id = p_tenant_id and pedido_cd_id = p_pedido_id;

  if v_total_qtd = 0 then
    raise exception 'pedido sem itens';
  end if;

  update public.pedidos_cd set total_qtd = v_total_qtd, total_valor = v_total_valor
  where tenant_id = p_tenant_id and id = p_pedido_id;

  -- Acima do limite e sem aprovação explícita: não reserva nada
  if (v_total_qtd > v_cfg.limite_automatico_qtd or v_total_valor > v_cfg.limite_automatico_valor) and not p_aprovado then
    return jsonb_build_object(
      'pedido_id', p_pedido_id,
      'status', 'aguardando_aprovacao',
      'motivo', 'acima_do_limite',
      'total_qtd', v_total_qtd,
      'total_valor', v_total_valor
    );
  end if;

  v_tem_cd := exists (select 1 from public.regras_saida r
                      where r.tenant_id = p_tenant_id and r.canal = v_pedido.canal and r.local_tipo = 'cd');
  v_tem_loja := exists (select 1 from public.regras_saida r
                        where r.tenant_id = p_tenant_id and r.canal = v_pedido.canal and r.local_tipo = 'loja');
  v_efetivo := case when v_tem_cd then 'cd' else 'loja' end;

  for v_item in
    select produto_id, qtd from public.pedidos_cd_itens
    where tenant_id = p_tenant_id and pedido_cd_id = p_pedido_id
    order by produto_id
  loop
    v_falta := v_item.qtd;

    -- Fase 1: reserva no local efetivo (CD se o canal tiver CD; senão loja)
    for v_end in
      select s.endereco_id, e.local_id, (s.qtd - s.reservado) as livre
      from public.saldos s
      join public.enderecos e on e.tenant_id = s.tenant_id and e.id = s.endereco_id
      join public.locais l on l.tenant_id = e.tenant_id and l.id = e.local_id
      where s.tenant_id = p_tenant_id
        and s.produto_id = v_item.produto_id
        and l.tipo = v_efetivo
        and (s.qtd - s.reservado) > 0
      order by s.endereco_id
      for update of s
    loop
      exit when v_falta = 0;
      v_pega := least(v_falta, v_end.livre);
      update public.saldos set reservado = reservado + v_pega
      where tenant_id = p_tenant_id and produto_id = v_item.produto_id and endereco_id = v_end.endereco_id;
      insert into public.reservas (tenant_id, pedido_cd_id, produto_id, endereco_id, qtd)
      values (p_tenant_id, p_pedido_id, v_item.produto_id, v_end.endereco_id, v_pega);
      v_falta := v_falta - v_pega;
      if v_efetivo = 'cd' then
        v_reservado_cd := v_reservado_cd + v_pega;
      end if;
    end loop;

    -- Fase 2: falta no CD vira transferência automática loja → CD (ligada ao pedido)
    if v_efetivo = 'cd' and v_falta > 0 and v_tem_loja
       and v_cfg.politica_falta = 'transferencia_automatica' then
      for v_end in
        select s.endereco_id, e.local_id, (s.qtd - s.reservado) as livre
        from public.saldos s
        join public.enderecos e on e.tenant_id = s.tenant_id and e.id = s.endereco_id
        join public.locais l on l.tenant_id = e.tenant_id and l.id = e.local_id
        where s.tenant_id = p_tenant_id
          and s.produto_id = v_item.produto_id
          and l.tipo = 'loja'
          and (s.qtd - s.reservado) > 0
        order by s.endereco_id
        for update of s
      loop
        exit when v_falta = 0;
        v_pega := least(v_falta, v_end.livre);
        update public.saldos set reservado = reservado + v_pega
        where tenant_id = p_tenant_id and produto_id = v_item.produto_id and endereco_id = v_end.endereco_id;
        insert into public.reservas (tenant_id, pedido_cd_id, produto_id, endereco_id, qtd)
        values (p_tenant_id, p_pedido_id, v_item.produto_id, v_end.endereco_id, v_pega);

        select t.id into v_transf_id from public.transferencias t
        where t.tenant_id = p_tenant_id and t.pedido_cd_id = p_pedido_id
          and t.origem_local_id = v_end.local_id and t.status = 'pendente';
        if v_transf_id is null then
          insert into public.transferencias (tenant_id, origem_local_id, destino_local_id, pedido_cd_id)
          values (p_tenant_id, v_end.local_id, v_pedido.local_id, p_pedido_id)
          returning id into v_transf_id;
        end if;

        insert into public.transferencia_itens (tenant_id, transferencia_id, produto_id, qtd)
        values (p_tenant_id, v_transf_id, v_item.produto_id, v_pega)
        on conflict (tenant_id, transferencia_id, produto_id)
        do update set qtd = public.transferencia_itens.qtd + excluded.qtd;

        v_falta := v_falta - v_pega;
        v_transferido := v_transferido + v_pega;
      end loop;
    end if;

    v_falta_final := v_falta_final + v_falta;
  end loop;

  update public.pedidos_cd
  set status = 'autorizada', autorizada_em = now()
  where tenant_id = p_tenant_id and id = p_pedido_id;

  return jsonb_build_object(
    'pedido_id', p_pedido_id,
    'status', 'autorizada',
    'total_qtd', v_total_qtd,
    'total_valor', v_total_valor,
    'reservado_cd', v_reservado_cd,
    'transferido_para_cd', v_transferido,
    'falta_sem_cobertura', v_falta_final
  );
end;
$$;

revoke all on function public.cd_alocar_pedido(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.cd_alocar_pedido(uuid, uuid, boolean) to service_role;

comment on function public.cd_alocar_pedido(uuid, uuid, boolean) is 'M54-G4. Aloca pedido do CD: limite, reserva no CD, falta vira transferência loja → CD. Só service_role.';
