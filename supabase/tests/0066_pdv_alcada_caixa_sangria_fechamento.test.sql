-- Testes 0066 (atualizados para 0067: PIN do aprovador e retorno jsonb).
-- Rodar DEPOIS de aplicar 0066 e 0067, no staging. Tudo termina em ROLLBACK.
-- Esperado: NOTICE 'TODOS OS TESTES 0066 PASSARAM'.
-- Fixtures: tenant 7f2f05c7, aprovador 72d1f5ee (cash.adjust e cash.close), solicitante e2b88e26 (operador).
-- Limitação: o fluxo completo do comando de fechamento está em 0066_..._integracao.test.sql.

begin;

do $$
declare
  v_tenant uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3';
  v_approver uuid := '72d1f5ee-0e6b-4551-bba2-dff88a7766e1';
  v_requester uuid := 'e2b88e26-94b9-4ead-8955-9d22f98d269b';
  v_estab uuid;
  v_register uuid;
  v_session uuid;
  v_limit numeric;
  v_big numeric;
  v_expected numeric;
  v_res jsonb;
  v_auth_w uuid;
  v_auth_c uuid;
  v_amount_gravado numeric;
  v_nopriv uuid;
  v_bloqueou boolean;
begin
  if not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_requester and status = 'active')
     or not exists (select 1 from public.erp_tenant_memberships where tenant_id = v_tenant and user_id = v_approver and status = 'active') then
    raise exception 'AVISO: membros de teste ausentes no tenant; testes 0066 nao executados';
  end if;

  select id into v_estab from public.erp_establishments where tenant_id = v_tenant limit 1;
  if v_estab is null then
    raise exception 'AVISO: sem estabelecimento no tenant; testes 0066 nao executados';
  end if;

  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until)
  values (v_tenant, v_approver, extensions.crypt('4321', extensions.gen_salt('bf')), 0, null)
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;

  select coalesce((s.value ->> 'amount')::numeric, 500) into v_limit
    from public.erp_tenant_settings s
   where s.tenant_id = v_tenant and s.key = 'pdv.cash.withdrawal_limit_amount' and s.establishment_id is null;
  v_limit := coalesce(v_limit, 500);
  v_big := v_limit + 100;

  insert into public.erp_cash_registers (tenant_id, establishment_id, code, name)
  values (v_tenant, v_estab, 'T0066-' || substr(gen_random_uuid()::text, 1, 8), 'Caixa teste 0066')
  returning id into v_register;

  insert into public.erp_cash_sessions (tenant_id, cash_register_id, operator_id, opening_amount, status, idempotency_key)
  values (v_tenant, v_register, v_requester, 1000, 'open', 'test-0066-' || gen_random_uuid()::text)
  returning id into v_session;

  -- A. Função: security definer, search_path fixo, privilégios
  if not exists (select 1 from pg_proc p where p.proname = 'erp_authorize_cash_action' and p.prosecdef and p.proconfig @> array['search_path=""']) then
    raise exception 'FALHA A1: erp_authorize_cash_action sem security definer ou search_path';
  end if;
  if has_function_privilege('anon', 'public.erp_authorize_cash_action(uuid,uuid,text,numeric,uuid,text,text)', 'EXECUTE') then
    raise exception 'FALHA A2: anon pode executar a RPC';
  end if;
  if not has_function_privilege('authenticated', 'public.erp_authorize_cash_action(uuid,uuid,text,numeric,uuid,text,text)', 'EXECUTE') then
    raise exception 'FALHA A3: authenticated sem execucao da RPC';
  end if;

  -- B. Sangria dentro do limite pelo operador, sem autorização -> aceita
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at)
  values (v_tenant, v_session, 'withdrawal', 'out', 100, v_requester, 'w-small-' || gen_random_uuid()::text, 'Sangria pequena teste', now());

  -- C. Sangria acima do limite sem autorização -> 23514
  v_bloqueou := false;
  begin
    insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at)
    values (v_tenant, v_session, 'withdrawal', 'out', v_big, v_requester, 'w-big-noauth-' || gen_random_uuid()::text, 'Sangria sem alcada', now());
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA C: sangria acima do limite aceita sem autorizacao'; end if;

  -- D. Aprovador autoriza sangria acima do limite com PIN certo -> authorized
  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'withdrawal', v_big, v_requester, 'Sangria teste com alcada', '4321');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA D: autorizacao valida de sangria nao gravada (%)', v_res; end if;
  v_auth_w := (v_res->>'authorization_id')::uuid;

  -- E. Autoaprovação de sangria -> 23514
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'withdrawal', v_big, v_requester, 'Autoaprovacao teste', '4321');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA E: autoaprovacao de sangria aceita'; end if;

  -- F. Autorização para sangria dentro do limite -> 23514
  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'withdrawal', 100, v_requester, 'Dentro do limite teste', '4321');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA F: alcada gravada para sangria dentro do limite'; end if;

  -- G. Sangria acima do limite com valor diferente da autorização -> 23514
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  v_bloqueou := false;
  begin
    insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at, authorization_id)
    values (v_tenant, v_session, 'withdrawal', 'out', v_big + 1, v_requester, 'w-mismatch-' || gen_random_uuid()::text, 'Valor divergente', now(), v_auth_w);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA G: autorizacao aceita com valor divergente'; end if;

  -- H. Sangria acima do limite com a autorização correta -> aceita
  insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at, authorization_id)
  values (v_tenant, v_session, 'withdrawal', 'out', v_big, v_requester, 'w-big-auth-' || gen_random_uuid()::text, 'Sangria autorizada', now(), v_auth_w);

  -- I. Reuso da mesma autorização -> 23505
  v_bloqueou := false;
  begin
    insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at, authorization_id)
    values (v_tenant, v_session, 'withdrawal', 'out', v_big, v_requester, 'w-reuse-' || gen_random_uuid()::text, 'Reuso teste', now(), v_auth_w);
  exception when unique_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA I: autorizacao reutilizada em nova sangria'; end if;

  -- J. Autorização informada em sangria dentro do limite -> 23514
  v_bloqueou := false;
  begin
    insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at, authorization_id)
    values (v_tenant, v_session, 'withdrawal', 'out', 50, v_requester, 'w-inside-auth-' || gen_random_uuid()::text, 'Dentro com auth', now(), v_auth_w);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA J: autorizacao aceita em sangria dentro do limite'; end if;

  -- K. Autorização informada em tipo que não é sangria -> 23514
  v_bloqueou := false;
  begin
    insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at, authorization_id)
    values (v_tenant, v_session, 'adjustment', 'out', 10, v_requester, 'adj-auth-' || gen_random_uuid()::text, 'Ajuste com auth', now(), v_auth_w);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA K: autorizacao aceita em movimento que nao e sangria'; end if;

  -- L. Usuário sem membership no tenant (logo sem cash.adjust) -> 42501
  v_nopriv := gen_random_uuid();
  perform set_config('request.jwt.claims', json_build_object('sub', v_nopriv)::text, true);
  perform set_config('request.jwt.claim.sub', v_nopriv::text, true);
  if (select erp_security.has_permission(v_tenant, 'cash.adjust')) then
    raise exception 'FALHA L0: usuario de teste sem membership tem cash.adjust';
  end if;
  v_bloqueou := false;
  begin
    insert into public.erp_cash_movements (tenant_id, cash_session_id, type, direction, amount, created_by, idempotency_key, reason, occurred_at)
    values (v_tenant, v_session, 'withdrawal', 'out', 20, v_nopriv, 'w-nopriv-' || gen_random_uuid()::text, 'Sem permissao', now());
  exception when insufficient_privilege then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA L: sangria aceita sem cash.adjust'; end if;

  -- M. Saldo esperado: 1000 - 100 - v_big
  v_expected := public.erp_cash_session_expected_v1(v_tenant, v_session);
  if v_expected is distinct from (1000 - 100 - v_big) then
    raise exception 'FALHA M: saldo esperado divergente (esperado %, obtido %)', 1000 - 100 - v_big, v_expected;
  end if;

  -- N. Diferença sem autorização -> 23514
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  v_bloqueou := false;
  begin
    perform public.erp_assert_cash_close_authorized_v1(v_tenant, v_session, v_expected, v_expected - 10, null);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA N: diferenca de caixa aceita sem autorizacao'; end if;

  -- O. Aprovador autoriza a diferença exata com PIN certo -> valor absoluto gravado
  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'close', v_expected - 10, v_requester, 'Diferenca teste', '4321');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA O: alcada de fechamento nao gravada (%)', v_res; end if;
  v_auth_c := (v_res->>'authorization_id')::uuid;
  select amount into v_amount_gravado from public.erp_cash_authorizations where id = v_auth_c;
  if v_amount_gravado is distinct from 10 then
    raise exception 'FALHA O2: valor da autorizacao de fechamento diferente da diferenca (%)', v_amount_gravado;
  end if;

  -- P. Autorização de fechamento sem diferença -> 23514
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'close', v_expected, v_requester, 'Sem diferenca teste', '4321');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA P: alcada de fechamento gravada sem diferenca'; end if;

  -- Q. Autoaprovação de fechamento -> 23514
  perform set_config('request.jwt.claims', json_build_object('sub', v_requester)::text, true);
  perform set_config('request.jwt.claim.sub', v_requester::text, true);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'close', v_expected - 10, v_requester, 'Autoaprovacao fechamento', '4321');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA Q: autoaprovacao de fechamento aceita'; end if;

  -- R. Helper aceita diferença com autorização exata e solicitante correto
  perform public.erp_assert_cash_close_authorized_v1(v_tenant, v_session, v_expected, v_expected - 10, v_auth_c);

  -- S. Helper rejeita autorização com valor divergente -> 23514
  v_bloqueou := false;
  begin
    perform public.erp_assert_cash_close_authorized_v1(v_tenant, v_session, v_expected, v_expected - 9, v_auth_c);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA S: autorizacao de fechamento aceita com valor divergente'; end if;

  -- T. Sem diferença, sem autorização -> passa
  perform public.erp_assert_cash_close_authorized_v1(v_tenant, v_session, v_expected, v_expected, null);

  -- U. Autorização já consumida por sessão -> 23514
  update public.erp_cash_sessions set closing_authorization_id = v_auth_c where id = v_session;
  v_bloqueou := false;
  begin
    perform public.erp_assert_cash_close_authorized_v1(v_tenant, v_session, v_expected, v_expected - 10, v_auth_c);
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA U: autorizacao de fechamento reutilizada'; end if;
  update public.erp_cash_sessions set closing_authorization_id = null where id = v_session;

  -- V. Autorização em sessão já fechada -> 55000
  update public.erp_cash_sessions set status = 'closed', closed_at = now(), counted_amount = v_expected - 10 where id = v_session;
  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_cash_action(v_tenant, v_session, 'close', v_expected - 10, v_requester, 'Sessao fechada teste', '4321');
  exception when sqlstate '55000' then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA V: autorizacao aceita em sessao fechada'; end if;

  raise notice 'TODOS OS TESTES 0066 PASSARAM';
end
$$;

rollback;
