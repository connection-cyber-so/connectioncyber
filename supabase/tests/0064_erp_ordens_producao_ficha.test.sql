-- Testes 0064. Rodar DEPOIS de aplicar a migration 0064, no staging.
-- Cria fixtures com nomes aleatórios e tudo termina em ROLLBACK: nada persiste.
-- Esperado: nenhuma exceção; NOTICE 'TODOS OS TESTES 0064 PASSARAM'.

begin;

do $$
declare
  v_tenant uuid;
  v_estab uuid;
  v_unit uuid;
  v_outra_unit uuid;
  v_item_prod uuid;
  v_item_insumo uuid;
  v_comp uuid;
  v_ordem uuid;
  v_key text := 'teste-0064-' || substr(md5(random()::text), 1, 12);
  v_qtd numeric;
  v_n integer;
  v_bloqueou boolean;
begin
  select e.tenant_id, e.id into v_tenant, v_estab
    from public.erp_establishments e
   order by e.created_at nulls last
   limit 1;

  if v_tenant is null then
    raise notice 'AVISO: staging sem estabelecimento; testes 0064 pulados';
    return;
  end if;

  -- Fixtures
  insert into public.erp_units (tenant_id, code, name, dimension, decimal_scale)
  values (v_tenant, upper(substr(md5(random()::text), 1, 10)), 'Unidade teste', 'count', 0)
  returning id into v_unit;

  insert into public.erp_units (tenant_id, code, name, dimension, decimal_scale)
  values (v_tenant, upper(substr(md5(random()::text), 1, 10)), 'Outra unidade teste', 'count', 0)
  returning id into v_outra_unit;

  insert into public.erp_catalog_items (tenant_id, kind, code, name, base_unit_id)
  values (v_tenant, 'prepared', 'T' || upper(substr(md5(random()::text), 1, 10)), 'Bolo teste', v_unit)
  returning id into v_item_prod;

  insert into public.erp_catalog_items (tenant_id, kind, code, name, base_unit_id)
  values (v_tenant, 'ingredient', 'T' || upper(substr(md5(random()::text), 1, 10)), 'Farinha teste', v_unit)
  returning id into v_item_insumo;

  insert into public.erp_item_compositions (tenant_id, item_id, kind, yield_quantity, yield_unit_id)
  values (v_tenant, v_item_prod, 'recipe', 12, v_unit)
  returning id into v_comp;

  insert into public.erp_item_composition_lines (tenant_id, composition_id, component_item_id, quantity, unit_id)
  values (v_tenant, v_comp, v_item_insumo, 2, v_unit);

  -- A. Ordem válida em rascunho: 3 de 12 -> fator 0,25 -> 2 * 0,25 = 0,5
  insert into public.erp_production_orders
    (tenant_id, establishment_id, item_id, composition_id, unit_id, quantity, idempotency_key)
  values (v_tenant, v_estab, v_item_prod, v_comp, v_unit, 3, v_key)
  returning id into v_ordem;

  select required_quantity into v_qtd
    from public.erp_production_order_requirements
   where production_order_id = v_ordem;
  if v_qtd is distinct from 0.5 then
    raise exception 'FALHA A: necessidade esperada 0.5, obtida %', v_qtd;
  end if;

  -- B. Perda de 10% entra na conta -> 0,55
  update public.erp_item_composition_lines set loss_percent = 10
   where tenant_id = v_tenant and composition_id = v_comp;
  select required_quantity into v_qtd
    from public.erp_production_order_requirements
   where production_order_id = v_ordem;
  if v_qtd is distinct from 0.55 then
    raise exception 'FALHA B: necessidade com perda esperada 0.55, obtida %', v_qtd;
  end if;

  -- C. Item que não é o produzido -> bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_production_orders
      (tenant_id, establishment_id, item_id, composition_id, unit_id, quantity, idempotency_key)
    values (v_tenant, v_estab, v_item_insumo, v_comp, v_unit, 1, v_key || '-c');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA C: ficha de outro item aceita'; end if;

  -- D. Unidade diferente da unidade de rendimento -> bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_production_orders
      (tenant_id, establishment_id, item_id, composition_id, unit_id, quantity, idempotency_key)
    values (v_tenant, v_estab, v_item_prod, v_comp, v_outra_unit, 1, v_key || '-d');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA D: unidade divergente aceita'; end if;

  -- E. Quantidade zero -> bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_production_orders
      (tenant_id, establishment_id, item_id, composition_id, unit_id, quantity, idempotency_key)
    values (v_tenant, v_estab, v_item_prod, v_comp, v_unit, 0, v_key || '-e');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA E: quantidade zero aceita'; end if;

  -- F. Ficha inativa -> nova ordem bloqueada
  update public.erp_item_compositions set active = false
   where tenant_id = v_tenant and id = v_comp;
  v_bloqueou := false;
  begin
    insert into public.erp_production_orders
      (tenant_id, establishment_id, item_id, composition_id, unit_id, quantity, idempotency_key)
    values (v_tenant, v_estab, v_item_prod, v_comp, v_unit, 1, v_key || '-f');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA F: ficha inativa aceita'; end if;
  update public.erp_item_compositions set active = true
   where tenant_id = v_tenant and id = v_comp;

  -- G. Chave de idempotência repetida -> bloqueado
  v_bloqueou := false;
  begin
    insert into public.erp_production_orders
      (tenant_id, establishment_id, item_id, composition_id, unit_id, quantity, idempotency_key)
    values (v_tenant, v_estab, v_item_prod, v_comp, v_unit, 1, v_key);
  exception when unique_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA G: idempotencia nao aplicada'; end if;

  -- H. Status cancelado sem cancelled_at -> bloqueado
  v_bloqueou := false;
  begin
    update public.erp_production_orders set status = 'cancelled'
     where id = v_ordem;
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA H: cancelamento sem data aceito'; end if;

  -- I. Ordem cancelada sai da visão de necessidades
  update public.erp_production_orders set status = 'cancelled', cancelled_at = now()
   where id = v_ordem;
  select count(*) into v_n from public.erp_production_order_requirements
   where production_order_id = v_ordem;
  if v_n <> 0 then raise exception 'FALHA I: ordem cancelada ainda aparece na visao (%)', v_n; end if;

  raise notice 'TODOS OS TESTES 0064 PASSARAM';
end
$$;

rollback;
