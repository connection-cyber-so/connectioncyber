-- Teste de integração 0066: fechamento de caixa pela camada de comandos (erp_command_close_cash_v1).
-- Rodar DEPOIS de aplicar a migration 0066, no staging. Tudo termina em ROLLBACK.
-- Esperado: NOTICE 'TESTE INTEGRACAO 0066 PASSOU'.
-- Fixtures: tenant 7f2f05c7, aprovador 72d1f5ee (cash.adjust e cash.close), solicitante e2b88e26 (operador, cash.close).

begin;

do $$
declare
  v_tenant uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3';
  v_approver uuid := '72d1f5ee-0e6b-4551-bba2-dff88a7766e1';
  v_requester uuid := 'e2b88e26-94b9-4ead-8955-9d22f98d269b';
  v_estab uuid;
  v_register uuid;
  v_session uuid;
  v_auth uuid;
  v_res_auth jsonb;
  v_expected numeric;
  v_counted numeric;
  v_payload jsonb;
  v_hash text;
  v_req text;
  v_result jsonb;
  v_status text;
  v_diff numeric;
  v_bloqueou boolean;
begin
  if not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_requester and status = 'active')
     or not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_approver and status = 'active') then
    raise exception 'AVISO: membros de teste ausentes; teste de integracao 0066 nao executado';
  end if;
  if not exists (select 1 from public.erp_resolve_tenant_capabilities(v_tenant, now()) c where c.capability_key = 'sales.pos' and c.status in ('trial', 'active')) then
    raise exception 'AVISO: capacidade sales.pos inativa no tenant de teste; teste de integracao 0066 nao executado';
  end if;

  select id into v_estab from public.erp_establishments where tenant_id = v_tenant limit 1;

  insert into public.erp_cash_registers (tenant_id, establishment_id, code, name)
  values (v_tenant, v_estab, 'T0066I-' || substr(gen_random_uuid()::text, 1, 8), 'Caixa integracao 0066')
  returning id into v_register;

  insert into public.erp_cash_sessions (tenant_id, cash_register_id, operator_id, opening_amount, status, idempotency_key)
  values (v_tenant, v_register, v_requester, 1000, 'open', 'test-0066i-' || gen_random_uuid()::text)
  returning id into v_session;

  -- Operador faz uma sangria pequena (dentro do limite)
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at)
  values (v_tenant, v_session, 'withdrawal', 'out', 100, v_requester, 'w-int-' || gen_random_uuid()::text, 'Sangria integracao', now());

  v_expected := public.erp_cash_session_expected_v1(v_tenant, v_session);
  if v_expected <> 900 then raise exception 'FALHA 0: saldo esperado diferente de 900 (%)', v_expected; end if;
  v_counted := 890; -- diferença de -10

  -- 1. Fechamento com diferença sem autorização -> 23514
  v_req := 'test-0066i-close-a-' || gen_random_uuid()::text;
  v_payload := jsonb_build_object('cashSessionId', v_session, 'countedAmount', v_counted);
  v_hash := encode(extensions.digest(convert_to(v_payload::text, 'UTF8'), 'sha256'), 'hex');
  v_bloqueou := false;
  begin
    perform public.erp_command_close_cash_v1(v_tenant, v_req, v_hash, v_payload);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA 1: fechamento com diferenca aceito sem autorizacao'; end if;

  -- 2. Aprovador autoriza a diferença exata
  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until)
  values (v_tenant, v_approver, extensions.crypt('4321', extensions.gen_salt('bf')), 0, null)
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;
  v_res_auth := public.erp_authorize_cash_action(v_tenant, v_session, 'close', v_counted, v_requester, 'Diferenca integracao', '4321');
  if v_res_auth->>'status' <> 'authorized' then raise exception 'FALHA 2: autorizacao de fechamento nao gravada (%)', v_res_auth; end if;
  v_auth := (v_res_auth->>'authorization_id')::uuid;

  -- 3. Operador fecha com a autorização -> closed, diferença gravada
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  v_req := 'test-0066i-close-b-' || gen_random_uuid()::text;
  v_payload := jsonb_build_object('cashSessionId', v_session, 'countedAmount', v_counted, 'authorizationId', v_auth);
  v_hash := encode(extensions.digest(convert_to(v_payload::text, 'UTF8'), 'sha256'), 'hex');
  v_result := public.erp_command_close_cash_v1(v_tenant, v_req, v_hash, v_payload);
  if v_result->>'status' is distinct from 'closed' then
    raise exception 'FALHA 3: resultado do fechamento inesperado: %', v_result;
  end if;

  select status, difference_amount into v_status, v_diff from public.erp_cash_sessions where id = v_session;
  if v_status <> 'closed' then raise exception 'FALHA 3b: sessao nao fechada (%)', v_status; end if;
  if v_diff <> -10 then raise exception 'FALHA 3c: difference_amount gravado diferente de -10 (%)', v_diff; end if;

  -- 4. Replay idempotente: mesmo request_id e hash devolvem o resultado salvo, sem erro
  v_result := public.erp_command_close_cash_v1(v_tenant, v_req, v_hash, v_payload);
  if v_result->>'status' is distinct from 'closed' then
    raise exception 'FALHA 4: replay nao devolveu o resultado salvo';
  end if;

  raise notice 'TESTE INTEGRACAO 0066 PASSOU';
end
$$;

rollback;
