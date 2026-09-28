-- ConnectionCyber — M21-G6: estende o provisionamento protegido do piloto (M18, migration
-- 0034) para o caso "1 tenant, N estabelecimentos, N donos" — hoje
-- `erp_prepare_pilot_provisioning_v1` sempre cria um tenant novo, então rodá-la duas vezes
-- para o mesmo cliente falha com "pilot identity already exists". Isso bloqueava o caso real
-- da Loja da Benção (MEI Aldo Augusto Ribeiro + MEI Eliane Aparecida Moreira Ribeiro, 1 tenant
-- combinado, 2 CNPJs, 2 donos, "uma coisa só" com abas — decisão registrada em
-- IMPLANTACAO-CASA-DE-BOLOS-MEI.md, confirmada pelo usuário em 08/09/2026).
--
-- Adiciona `erp_prepare_pilot_establishment_v1(p_tenant_slug, p_request)`: mesmo desenho
-- fail-closed / idempotente / auditável do M18 (advisory lock por idempotencyKey, replay
-- seguro, rejeita chave protegida/campo desconhecido no payload), mas anexa um
-- estabelecimento (+ dono próprio) a um tenant JÁ existente em vez de criar tenant novo.
-- Reaproveita SEM alteração `erp_record_pilot_auth_identity_v1` e
-- `erp_finalize_pilot_identity_v1` — as duas operam só sobre `run_id`/outbox, nunca assumem
-- criação de tenant, então servem aos dois fluxos (tenant novo E estabelecimento adicional)
-- sem nenhuma mudança de código nelas.
begin;

-- Achado deste gate (validado localmente antes de qualquer escrita real): o índice único
-- `erp_establishments_tenant_state_registration_unique` (M18, migration 0034) trata o
-- literal 'ISENTO' como se fosse um número de IE real — então dois estabelecimentos
-- isentos de IE no MESMO tenant colidiam, mesmo sem nenhum conflito de verdade. Isso nunca
-- apareceu antes porque, até este gate, nenhum tenant tinha mais de um estabelecimento. É
-- exatamente o caso real da Loja da Benção se Aldo e Eliane forem os dois isentos de IE.
-- Restringe a unicidade a números de IE de fato, preservando a garantia original pra IE real.
drop index if exists public.erp_establishments_tenant_state_registration_unique;
create unique index erp_establishments_tenant_state_registration_unique
  on public.erp_establishments(tenant_id, state_registration)
  where state_registration is not null and state_registration <> 'ISENTO';

create or replace function public.erp_prepare_pilot_establishment_v1(p_tenant_slug text, p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_run public.erp_identity_provisioning_runs%rowtype;
  v_tenant_id uuid;
  v_establishment_id uuid;
  v_outbox_id uuid;
  v_hash text;
  v_kind text;
  v_allowed text[] := array[
    'idempotencyKey','establishmentCode','establishmentKind','legalName','tradeName',
    'cnpj','stateRegistration','verticalCode','ownerSubjectKey','ownerEmailRef'
  ];
begin
  if auth.role() <> 'service_role' then
    raise exception using errcode = '42501', message = 'broker only';
  end if;

  if jsonb_typeof(p_request) <> 'object'
     or (p_request - v_allowed) <> '{}'::jsonb
     or p_request::text ~* '"(password|senha|secret|token|credential|private_key|service_role|certificate|pfx|p12|csc)"[[:space:]]*:' then
    raise exception using errcode = '22023', message = 'unsafe establishment request';
  end if;

  v_kind := coalesce(p_request->>'establishmentKind', 'branch');
  if coalesce(p_request->>'idempotencyKey','') !~ '^[a-z0-9][a-z0-9._:-]{7,127}$'
     or v_kind not in ('headquarters','branch','unit')
     or coalesce(p_request->>'cnpj','') !~ '^[0-9]{14}$'
     or coalesce(p_request->>'stateRegistration','') !~ '^[A-Z0-9]{2,20}$'
     or coalesce(p_request->>'verticalCode','') !~ '^[a-z][a-z0-9_.-]{1,95}$'
     or coalesce(p_request->>'ownerSubjectKey','') !~ '^[a-z][a-z0-9._-]{2,95}$'
     or coalesce(p_request->>'ownerEmailRef','') !~ '^protected:[A-Z][A-Z0-9_]{2,95}$' then
    raise exception using errcode = '22023', message = 'invalid establishment request';
  end if;

  select id into v_tenant_id from public.tenants where slug = p_tenant_slug;
  if v_tenant_id is null then
    raise exception using errcode = '55000', message = 'tenant not found';
  end if;
  if not exists (select 1 from public.erp_business_verticals where code = p_request->>'verticalCode') then
    raise exception using errcode = '55000', message = 'unknown vertical';
  end if;

  v_hash := encode(extensions.digest(convert_to(p_request::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_request->>'idempotencyKey', 0));
  select * into v_run from public.erp_identity_provisioning_runs where idempotency_key = p_request->>'idempotencyKey' for update;
  if found then
    if v_run.manifest_sha256 <> v_hash then
      raise exception using errcode = '23505', message = 'idempotency conflict';
    end if;
    select id into v_establishment_id from public.erp_establishments where tenant_id = v_tenant_id and cnpj = p_request->>'cnpj';
    return jsonb_build_object('runId', v_run.id, 'tenantId', v_tenant_id, 'establishmentId', v_establishment_id, 'replayed', true, 'status', v_run.status);
  end if;

  if exists (select 1 from public.erp_establishments where cnpj = p_request->>'cnpj') then
    raise exception using errcode = '23505', message = 'pilot identity already exists';
  end if;

  insert into public.erp_identity_provisioning_runs(idempotency_key, manifest_sha256, schema_version, environment, execution_mode, status, subject_count, started_at, summary)
  values (p_request->>'idempotencyKey', v_hash, 1, 'staging', 'apply', 'running', 1, now(), jsonb_build_object('pilot', true, 'identity_values_logged', false, 'kind', 'establishment_addition', 'tenantId', v_tenant_id::text))
  returning * into v_run;

  insert into public.erp_establishments(tenant_id, code, kind, legal_name, trade_name, cnpj, state_registration, vertical_code)
  values (v_tenant_id, upper(p_request->>'establishmentCode'), v_kind, btrim(p_request->>'legalName'), btrim(p_request->>'tradeName'), p_request->>'cnpj', p_request->>'stateRegistration', p_request->>'verticalCode')
  returning id into v_establishment_id;

  insert into public.erp_identity_provisioning_steps(run_id, step_key, subject_key, action, status, tenant_id, finished_at) values
    (v_run.id, 'm21g6.01:create_establishment', p_request->>'ownerSubjectKey', 'create_establishment', 'completed', v_tenant_id, now()),
    (v_run.id, 'm21g6.02:enqueue_auth_invitation', p_request->>'ownerSubjectKey', 'enqueue_auth_invitation', 'completed', v_tenant_id, now()),
    (v_run.id, 'm21g6.03:finalize_identity', p_request->>'ownerSubjectKey', 'finalize_identity', 'planned', v_tenant_id, null),
    (v_run.id, 'm21g6.04:require_mfa', p_request->>'ownerSubjectKey', 'require_mfa', 'planned', v_tenant_id, null);

  insert into public.erp_auth_invitation_outbox(run_id, tenant_id, subject_key, email_ref, payload_hash)
  values (v_run.id, v_tenant_id, p_request->>'ownerSubjectKey', p_request->>'ownerEmailRef', v_hash)
  returning id into v_outbox_id;

  return jsonb_build_object('runId', v_run.id, 'tenantId', v_tenant_id, 'establishmentId', v_establishment_id, 'outboxId', v_outbox_id, 'replayed', false, 'status', 'awaiting_auth_dispatch');
end$$;

revoke execute on function public.erp_prepare_pilot_establishment_v1(text, jsonb) from public, anon, authenticated;
grant execute on function public.erp_prepare_pilot_establishment_v1(text, jsonb) to service_role;

commit;
