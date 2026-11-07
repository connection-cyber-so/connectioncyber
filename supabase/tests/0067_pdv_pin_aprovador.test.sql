-- Testes 0067 (PIN do aprovador), atualizados para 0068 (PIN cadastrado pelo gerente).
-- Rodar DEPOIS de aplicar 0067 e 0068, no staging. Tudo termina em ROLLBACK.
-- Esperado: NOTICE 'TESTES 0067 PASSARAM'.
begin;

do $$
declare
  v_tenant uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3';
  v_approver uuid := '72d1f5ee-0e6b-4551-bba2-dff88a7766e1';
  v_requester uuid := 'e2b88e26-94b9-4ead-8955-9d22f98d269b';
  v_manager uuid;
  v_estab uuid;
  v_register uuid;
  v_session uuid;
  v_limit numeric;
  v_cash_limit numeric;
  v_res jsonb;
  v_status text;
  v_count int;
  v_locked timestamptz;
  v_failed int;
  v_stranger uuid := gen_random_uuid();
  v_bloqueou boolean;
begin
  if not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_requester and status = 'active')
     or not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_approver and status = 'active') then
    raise exception 'AVISO: membros de teste ausentes; testes 0067 nao executados';
  end if;
  select id into v_estab from public.erp_establishments where tenant_id = v_tenant limit 1;

  -- Gerente de teste fixo: e2b88e26 (memberships.manage). Não usar o aprovador (72d1f5ee):
  -- ele também tem memberships.manage e, como alvo, cairia no auto-PIN (bloqueado pela 0069).
  v_manager := v_requester;
  if not exists (
    select 1 from public.erp_tenant_memberships m
      join public.erp_membership_roles mr on mr.tenant_id = m.tenant_id and mr.membership_id = m.id
      join public.erp_role_permissions rp on rp.tenant_id = mr.tenant_id and rp.role_id = mr.role_id
      join public.erp_permissions pe on pe.id = rp.permission_id
     where m.tenant_id = v_tenant and m.user_id = v_manager and m.status = 'active' and pe.key = 'memberships.manage'
  ) then
    raise exception 'AVISO: gerente de teste sem memberships.manage; testes 0067 nao executados';
  end if;

  -- A. Assinaturas e privilégios
  if to_regprocedure('public.erp_authorize_discount(uuid,uuid,uuid,uuid,numeric,numeric,text)') is not null then
    raise exception 'FALHA A1: assinatura antiga de erp_authorize_discount ainda existe';
  end if;
  if to_regprocedure('public.erp_authorize_cash_action(uuid,uuid,text,numeric,uuid,text)') is not null then
    raise exception 'FALHA A2: assinatura antiga de erp_authorize_cash_action ainda existe';
  end if;
  if to_regprocedure('public.erp_set_approver_pin(uuid,text,text)') is not null then
    raise exception 'FALHA A3: autoatendimento de PIN ainda existe';
  end if;
  if has_function_privilege('anon', 'public.erp_manager_set_approver_pin(uuid,uuid,text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.erp_check_approver_pin(uuid,uuid,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.erp_check_approver_pin(uuid,uuid,text)', 'EXECUTE') then
    raise exception 'FALHA A4: funcao de PIN exposta indevidamente';
  end if;

  -- PIN inicial conhecido do aprovador (superuser de teste)
  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until)
  values (v_tenant, v_approver, extensions.crypt('4321', extensions.gen_salt('bf')), 0, null)
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;

  select coalesce((s.value ->> 'percent')::numeric, 5) into v_limit
    from public.erp_tenant_settings s
   where s.tenant_id = v_tenant and s.key = 'pdv.discount.auto_limit_percent' and s.establishment_id is null;
  v_limit := coalesce(v_limit, 5);

  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);

  -- B. PIN ausente: nada é gravado
  delete from public.erp_approver_pins where tenant_id = v_tenant and user_id = v_approver;
  select count(*) into v_count from public.erp_discount_authorizations where tenant_id = v_tenant;
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Teste sem PIN', '4321');
  if v_res->>'status' <> 'pin_missing' then raise exception 'FALHA B: esperado pin_missing, obtido %', v_res; end if;
  if (select count(*) from public.erp_discount_authorizations where tenant_id = v_tenant) <> v_count then
    raise exception 'FALHA B2: autorizacao gravada sem PIN';
  end if;
  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until)
  values (v_tenant, v_approver, extensions.crypt('4321', extensions.gen_salt('bf')), 0, null);

  -- C. PIN errado: pin_invalid e contador sobe
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Teste PIN errado', '0000');
  if v_res->>'status' <> 'pin_invalid' then raise exception 'FALHA C: esperado pin_invalid, obtido %', v_res; end if;
  select failed_attempts into v_failed from public.erp_approver_pins where tenant_id = v_tenant and user_id = v_approver;
  if v_failed <> 1 then raise exception 'FALHA C2: contador esperado 1, obtido %', v_failed; end if;

  -- D. Quinto erro bloqueia; PIN certo durante o bloqueio é recusado
  perform public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Erro 2', '0000');
  perform public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Erro 3', '0000');
  perform public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Erro 4', '0000');
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Erro 5', '0000');
  if v_res->>'status' <> 'pin_locked' then raise exception 'FALHA D: quinto erro deveria bloquear, obtido %', v_res; end if;
  select locked_until into v_locked from public.erp_approver_pins where tenant_id = v_tenant and user_id = v_approver;
  if v_locked is null or v_locked <= now() then raise exception 'FALHA D2: bloqueio sem janela futura'; end if;

  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Certo bloqueado', '4321');
  if v_res->>'status' <> 'pin_locked' then raise exception 'FALHA D3: PIN certo aceito durante bloqueio, obtido %', v_res; end if;
  if (select count(*) from public.erp_discount_authorizations where tenant_id = v_tenant and reason = 'Certo bloqueado') <> 0 then
    raise exception 'FALHA D4: autorizacao gravada durante bloqueio';
  end if;

  -- E. Fim do bloqueio (simulado) + PIN certo -> autorizado; contador zera
  update public.erp_approver_pins set locked_until = now() - interval '1 minute'
   where tenant_id = v_tenant and user_id = v_approver;
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Cortesia 0067', '4321');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA E: autorizacao valida recusada, obtido %', v_res; end if;
  if not exists (select 1 from public.erp_discount_authorizations
                  where id = (v_res->>'authorization_id')::uuid and approved_by = v_approver and requested_by = v_requester) then
    raise exception 'FALHA E2: autorizacao de desconto nao gravada corretamente';
  end if;
  select failed_attempts into v_failed from public.erp_approver_pins where tenant_id = v_tenant and user_id = v_approver;
  if v_failed <> 0 then raise exception 'FALHA E3: contador nao zerou apos PIN certo'; end if;

  -- F. Gerente cadastra novo PIN para o aprovador; PIN antigo deixa de valer
  perform set_config('request.jwt.claims', json_build_object('sub', v_manager)::text, true);
  perform set_config('request.jwt.claim.sub', v_manager::text, true);
  v_status := public.erp_manager_set_approver_pin(v_tenant, v_approver, '5555');
  if v_status <> 'ok' then raise exception 'FALHA F: gerente nao cadastrou PIN (%)', v_status; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Com PIN antigo', '4321');
  if v_res->>'status' <> 'pin_invalid' then raise exception 'FALHA F2: PIN antigo ainda aceito apos cadastro do gerente, obtido %', v_res; end if;
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Com PIN novo', '5555');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA F3: PIN novo recusado, obtido %', v_res; end if;

  -- F4. PIN fora do formato -> 22023 (sessão do gerente)
  perform set_config('request.jwt.claims', json_build_object('sub', v_manager)::text, true);
  perform set_config('request.jwt.claim.sub', v_manager::text, true);
  v_bloqueou := false;
  begin
    perform public.erp_manager_set_approver_pin(v_tenant, v_approver, '12');
  exception when sqlstate '22023' then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA F4: PIN com 2 digitos aceito'; end if;

  -- G. Usuário sem memberships.manage não cadastra PIN -> 42501
  perform set_config('request.jwt.claims', json_build_object('sub', v_stranger)::text, true);
  perform set_config('request.jwt.claim.sub', v_stranger::text, true);
  v_bloqueou := false;
  begin
    perform public.erp_manager_set_approver_pin(v_tenant, v_approver, '7777');
  exception when insufficient_privilege then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA G: usuario sem permissao cadastrou PIN'; end if;

  -- H. Caixa com PIN (aprovador): errado -> pin_invalid sem gravar; certo -> authorized
  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  insert into public.erp_cash_registers (tenant_id, establishment_id, code, name)
  values (v_tenant, v_estab, 'T0067-' || substr(gen_random_uuid()::text, 1, 8), 'Caixa teste 0067')
  returning id into v_register;
  insert into public.erp_cash_sessions (tenant_id, cash_register_id, operator_id, opening_amount, status, idempotency_key)
  values (v_tenant, v_register, v_requester, 1000, 'open', 'test-0067-' || gen_random_uuid()::text)
  returning id into v_session;

  select coalesce((s.value ->> 'amount')::numeric, 500) into v_cash_limit
    from public.erp_tenant_settings s
   where s.tenant_id = v_tenant and s.key = 'pdv.cash.withdrawal_limit_amount' and s.establishment_id is null;
  v_cash_limit := coalesce(v_cash_limit, 500);

  v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'withdrawal', v_cash_limit + 100, v_requester, 'Sangria PIN errado', '4321');
  if v_res->>'status' <> 'pin_invalid' then raise exception 'FALHA H: caixa com PIN antigo deveria ser pin_invalid, obtido %', v_res; end if;
  if exists (select 1 from public.erp_cash_authorizations where cash_session_id = v_session) then
    raise exception 'FALHA H2: autorizacao de caixa gravada com PIN errado';
  end if;

  v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'withdrawal', v_cash_limit + 100, v_requester, 'Sangria autorizada', '5555');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA H3: sangria com PIN certo recusada, obtido %', v_res; end if;

  -- I. Fechamento com diferença (saldo 1000, contado 900) e PIN certo -> authorized
  v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'close', 900, v_requester, 'Diferenca PIN', '5555');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA I: alcada de fechamento com PIN certo recusada, obtido %', v_res; end if;

  raise notice 'TESTES 0067 PASSARAM';
end
$$;

rollback;
