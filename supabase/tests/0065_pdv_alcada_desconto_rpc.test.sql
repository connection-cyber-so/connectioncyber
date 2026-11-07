-- Testes 0065 (atualizados para 0067: PIN do aprovador e retorno jsonb).
-- Rodar DEPOIS de aplicar 0065 e 0067, no staging. Tudo termina em ROLLBACK.
-- Esperado: NOTICE 'TODOS OS TESTES 0065 PASSARAM'.

begin;

do $$
declare
  v_tenant uuid;
  v_approver uuid;
  v_requester uuid;
  v_estab uuid;
  v_res jsonb;
  v_id uuid;
  v_bloqueou boolean;
  v_limit numeric;
  v_aprovador_gravado uuid;
  v_solicitante_gravado uuid;
begin
  select m.tenant_id, m.user_id into v_tenant, v_approver
    from public.erp_tenant_memberships m
    join public.erp_membership_roles mr on mr.tenant_id = m.tenant_id and mr.membership_id = m.id
    join public.erp_role_permissions rp on rp.tenant_id = mr.tenant_id and rp.role_id = mr.role_id
    join public.erp_permissions p on p.id = rp.permission_id
    join public.users u on u.id = m.user_id
    join public.tenants t on t.id = m.tenant_id
    join public.erp_establishments e on e.tenant_id = m.tenant_id
   where p.key = 'sales.discount' and m.status = 'active' and u.ativo and t.ativo
     and exists (
       select 1 from public.erp_tenant_memberships m2
        where m2.tenant_id = m.tenant_id and m2.status = 'active' and m2.user_id <> m.user_id
     )
   limit 1;

  if v_tenant is null then
    raise exception 'AVISO: sem aprovador com sales.discount e outro membro; testes 0065 nao executados';
  end if;

  select m.user_id into v_requester
    from public.erp_tenant_memberships m
    join public.users u on u.id = m.user_id
   where m.tenant_id = v_tenant and m.status = 'active' and u.ativo and m.user_id <> v_approver
   limit 1;
  if v_requester is null then
    raise exception 'AVISO: sem solicitante distinto no tenant; testes 0065 nao executados';
  end if;

  select id into v_estab from public.erp_establishments where tenant_id = v_tenant limit 1;

  -- PIN conhecido do aprovador (superuser de teste)
  insert into public.erp_approver_pins (tenant_id, user_id, pin_hash, failed_attempts, locked_until)
  values (v_tenant, v_approver, extensions.crypt('4321', extensions.gen_salt('bf')), 0, null)
  on conflict (tenant_id, user_id) do update
    set pin_hash = excluded.pin_hash, failed_attempts = 0, locked_until = null;

  -- A. Função: security definer, search_path fixo, anon sem execução, authenticated com execução
  perform 1 from pg_proc p
   where p.proname = 'erp_authorize_discount' and p.prosecdef and p.proconfig @> array['search_path=""'];
  if not found then raise exception 'FALHA A1: funcao sem security definer ou search_path'; end if;
  if has_function_privilege('anon', 'public.erp_authorize_discount(uuid,uuid,uuid,uuid,numeric,numeric,text,text)', 'EXECUTE') then
    raise exception 'FALHA A2: anon pode executar a RPC';
  end if;
  if not has_function_privilege('authenticated', 'public.erp_authorize_discount(uuid,uuid,uuid,uuid,numeric,numeric,text,text)', 'EXECUTE') then
    raise exception 'FALHA A3: authenticated sem execucao da RPC';
  end if;

  -- B. Insert direto removido para authenticated
  if has_table_privilege('authenticated', 'public.erp_discount_authorizations', 'INSERT') then
    raise exception 'FALHA B: insert direto ainda permitido para authenticated';
  end if;

  -- C. Sem sessão -> bloqueado (42501)
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, 10, 'Teste sem sessao', '4321');
  exception when insufficient_privilege then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA C: chamada sem sessao aceita'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);

  -- D. Usuário sem sales.discount como aprovador -> bloqueado (42501)
  perform set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid())::text, true);
  perform set_config('request.jwt.claim.sub', '', true);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, 10, 'Teste sem permissao', '4321');
  exception when insufficient_privilege then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA D: aprovador sem permissao aceito'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', v_approver)::text, true);
  perform set_config('request.jwt.claim.sub', v_approver::text, true);

  -- E. Solicitante igual ao aprovador -> bloqueado (23514)
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_approver, 10, 10, 'Teste autoaprovacao', '4321');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA E: autoaprovacao aceita'; end if;

  -- F. Solicitante que não é membro do tenant -> bloqueado (42501)
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_discount(v_tenant, v_estab, null, gen_random_uuid(), 10, 10, 'Teste nao membro', '4321');
  exception when insufficient_privilege then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA F: solicitante nao membro aceito'; end if;

  -- G. Desconto dentro do limite automático -> sem alçada (23514)
  select coalesce((s.value ->> 'percent')::numeric, 5) into v_limit
    from public.erp_tenant_settings s
   where s.tenant_id = v_tenant and s.key = 'pdv.discount.auto_limit_percent' and s.establishment_id is null;
  v_limit := coalesce(v_limit, 5);
  v_bloqueou := false;
  begin
    v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 1, v_limit - 1, 'Teste dentro do limite', '4321');
  exception when check_violation then
    v_bloqueou := true;
  end;
  if not v_bloqueou then raise exception 'FALHA G: desconto dentro do limite gerou alcada'; end if;

  -- H. Caso válido com PIN certo -> autorizado; campos gravados corretamente
  v_res := public.erp_authorize_discount(v_tenant, v_estab, null, v_requester, 10, v_limit + 5, 'Cortesia de teste', '4321');
  if v_res->>'status' <> 'authorized' then raise exception 'FALHA H: autorizacao valida nao gravada (%)', v_res; end if;
  v_id := (v_res->>'authorization_id')::uuid;

  select approved_by, requested_by into v_aprovador_gravado, v_solicitante_gravado
    from public.erp_discount_authorizations where id = v_id;
  if v_aprovador_gravado is distinct from v_approver then
    raise exception 'FALHA H2: approved_by gravado diferente do aprovador da sessao';
  end if;
  if v_solicitante_gravado is distinct from v_requester then
    raise exception 'FALHA H3: requested_by gravado diferente do solicitante';
  end if;

  raise notice 'TODOS OS TESTES 0065 PASSARAM';
end
$$;

rollback;
