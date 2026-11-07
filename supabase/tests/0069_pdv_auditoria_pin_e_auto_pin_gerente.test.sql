-- TESTE 0069 · auditoria do PIN e auto-PIN do gerente
-- Fixtures do staging: gerente = e2b88e26 (memberships.manage); aprovador = 72d1f5ee (alçada + memberships.manage).
-- Rodar dentro de transação; termina com rollback. Sem exceção = todos os cenários passaram.

begin;

do $$
declare
  v_tenant uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3';
  v_manager uuid := 'e2b88e26-94b9-4ead-8955-9d22f98d269b';
  v_target uuid := '72d1f5ee-0e6b-4551-bba2-dff88a7766e1';
  v_stranger uuid := gen_random_uuid();
  v_count_before int;
  v_count_after int;
  v_is_self boolean;
  v_changed_by uuid;
  v_status text;
  v_caught text;
begin
  if not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_manager and status = 'active')
     or not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_target and status = 'active') then
    raise exception 'AVISO: fixtures ausentes; teste 0069 não executado';
  end if;

  update public.erp_tenant_settings set value = '{"enabled": false}'::jsonb
   where tenant_id = v_tenant and key = 'pdv.alcada.allow_self_pin' and establishment_id is null;

  -- A) Auto-PIN desligado (padrão): gerente não cadastra o próprio PIN
  perform set_config('request.jwt.claims', json_build_object('sub', v_manager)::text, true);
  perform set_config('request.jwt.claim.sub', v_manager::text, true);
  v_caught := null;
  begin
    perform public.erp_manager_set_approver_pin(v_tenant, v_manager, '1111');
  exception when sqlstate '42501' then
    v_caught := '42501';
  end;
  if v_caught is distinct from '42501' then
    raise exception 'FALHA A: auto-PIN com configuração desligada deveria ser 42501';
  end if;

  -- B) Gerente cadastra PIN de outra pessoa: ok, auditoria com is_self = false e autor = gerente
  select count(*) into v_count_before from public.erp_approver_pin_audit where tenant_id = v_tenant;
  v_status := public.erp_manager_set_approver_pin(v_tenant, v_target, '4455');
  if v_status <> 'ok' then raise exception 'FALHA B: cadastro do aprovador recusado'; end if;
  select count(*) into v_count_after from public.erp_approver_pin_audit where tenant_id = v_tenant;
  if v_count_after <> v_count_before + 1 then raise exception 'FALHA B2: auditoria não gravada no cadastro'; end if;
  select is_self, changed_by into v_is_self, v_changed_by
    from public.erp_approver_pin_audit
   where tenant_id = v_tenant and target_user_id = v_target
   order by created_at desc, id desc limit 1;
  if v_is_self is distinct from false or v_changed_by <> v_manager then
    raise exception 'FALHA B3: auditoria com autor ou autoatribuição incorretos';
  end if;

  -- C) Ligando a configuração: gerente cadastra o próprio PIN, auditoria com is_self = true
  update public.erp_tenant_settings set value = '{"enabled": true}'::jsonb
   where tenant_id = v_tenant and key = 'pdv.alcada.allow_self_pin' and establishment_id is null;
  v_status := public.erp_manager_set_approver_pin(v_tenant, v_manager, '2468');
  if v_status <> 'ok' then raise exception 'FALHA C: auto-PIN com configuração ligada recusado'; end if;
  select is_self into v_is_self from public.erp_approver_pin_audit
   where tenant_id = v_tenant and target_user_id = v_manager
   order by created_at desc, id desc limit 1;
  if v_is_self is distinct from true then raise exception 'FALHA C2: auditoria de autoatribuição sem is_self'; end if;

  -- D) Auditoria é imutável: update e delete bloqueados
  v_caught := null;
  begin
    update public.erp_approver_pin_audit set is_self = not is_self where tenant_id = v_tenant;
  exception when sqlstate '42501' then v_caught := '42501';
  end;
  if v_caught is distinct from '42501' then raise exception 'FALHA D: update na auditoria não foi bloqueado'; end if;
  v_caught := null;
  begin
    delete from public.erp_approver_pin_audit where tenant_id = v_tenant;
  exception when sqlstate '42501' then v_caught := '42501';
  end;
  if v_caught is distinct from '42501' then raise exception 'FALHA D2: delete na auditoria não foi bloqueado'; end if;

  -- E) Ator sem vínculo no tenant não cadastra PIN
  perform set_config('request.jwt.claims', json_build_object('sub', v_stranger)::text, true);
  perform set_config('request.jwt.claim.sub', v_stranger::text, true);
  v_caught := null;
  begin
    perform public.erp_manager_set_approver_pin(v_tenant, v_target, '9999');
  exception when sqlstate '42501' then v_caught := '42501';
  end;
  if v_caught is distinct from '42501' then raise exception 'FALHA E: ator sem permissão cadastrou PIN'; end if;

  raise notice 'TESTES 0069 PASSARAM';
end
$$;

rollback;
