-- ConnectionCyber — M18: provisionamento protegido e idempotente do piloto.
begin;

alter table public.erp_establishments
  add column state_registration text,
  add constraint erp_establishments_state_registration_format
    check (state_registration is null or state_registration ~ '^[A-Z0-9]{2,20}$');
create unique index erp_establishments_tenant_state_registration_unique
  on public.erp_establishments(tenant_id,state_registration) where state_registration is not null;
create unique index tenants_domain_unique
  on public.tenants(lower(dominio)) where dominio is not null;

alter table public.erp_identity_provisioning_steps
  drop constraint erp_identity_provisioning_steps_action_check,
  add constraint erp_identity_provisioning_steps_action_check check (action in (
    'validate_identity','create_auth_identity','upsert_profile','upsert_membership','assign_roles','require_mfa','write_audit',
    'create_tenant','create_establishment','assign_capabilities','enqueue_auth_invitation','finalize_identity','compensate_auth_identity'
  ));

create table public.erp_auth_invitation_outbox (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.erp_identity_provisioning_runs(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  subject_key text not null check(subject_key~'^[a-z][a-z0-9._-]{2,95}$'),
  email_ref text not null check(email_ref~'^protected:[A-Z][A-Z0-9_]{2,95}$'),
  payload_hash text not null check(payload_hash~'^[a-f0-9]{64}$'),
  status text not null default'pending' check(status in('pending','processing','identity_created','sent','failed','compensation_required','compensated')),
  auth_user_id uuid,
  attempt_count integer not null default 0 check(attempt_count>=0),
  lease_until timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(run_id,subject_key),
  unique(tenant_id,id),
  check((status in('identity_created','sent','compensation_required','compensated'))=(auth_user_id is not null)),
  check(last_error_code is null or last_error_code~'^[A-Z0-9_:-]{3,100}$')
);
create index erp_auth_invitation_outbox_dispatch
  on public.erp_auth_invitation_outbox(status,lease_until,created_at);

create table public.erp_auth_identity_compensations (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.erp_identity_provisioning_runs(id) on delete cascade,
  outbox_id uuid not null references public.erp_auth_invitation_outbox(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  auth_user_id uuid not null,
  action text not null default'disable_then_delete' check(action='disable_then_delete'),
  status text not null default'planned' check(status in('planned','processing','completed','failed')),
  reason_hash text not null check(reason_hash~'^[a-f0-9]{64}$'),
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  unique(outbox_id),
  unique(tenant_id,id),
  check((status='completed')=(finished_at is not null))
);

create trigger trg_erp_auth_invitation_outbox_updated_at before update on public.erp_auth_invitation_outbox
for each row execute function public.set_updated_at();
alter table public.erp_auth_invitation_outbox enable row level security;
alter table public.erp_auth_identity_compensations enable row level security;
revoke all on public.erp_auth_invitation_outbox,public.erp_auth_identity_compensations from public,anon,authenticated;
grant all on public.erp_auth_invitation_outbox,public.erp_auth_identity_compensations to service_role;

create or replace function public.erp_prepare_pilot_provisioning_v1(p_request jsonb)returns jsonb
language plpgsql security definer set search_path=''as $$
declare v_run public.erp_identity_provisioning_runs%rowtype;v_tenant_id uuid;v_establishment_id uuid;v_role_id uuid;v_outbox_id uuid;v_hash text;v_capability text;v_allowed text[]:=array['idempotencyKey','slug','domain','displayName','vertical','legalName','tradeName','cnpj','stateRegistration','establishmentCode','ownerSubjectKey','ownerEmailRef','capabilities'];
begin
  if auth.role()<>'service_role'then raise exception using errcode='42501',message='broker only';end if;
  if jsonb_typeof(p_request)<>'object'or(p_request-v_allowed)<>'{}'::jsonb or p_request::text~*'"(password|senha|secret|token|credential|private_key|service_role|certificate|pfx|p12|csc)"[[:space:]]*:'then raise exception using errcode='22023',message='unsafe provisioning request';end if;
  if coalesce(p_request->>'idempotencyKey','')!~'^[a-z0-9][a-z0-9._:-]{7,127}$'or coalesce(p_request->>'slug','')!~'^[a-z][a-z0-9-]{2,63}$'or coalesce(p_request->>'domain','')!~'^[a-z0-9-]+(\.[a-z0-9-]+)+$'or coalesce(p_request->>'cnpj','')!~'^[0-9]{14}$'or coalesce(p_request->>'stateRegistration','')!~'^[A-Z0-9]{2,20}$'or coalesce(p_request->>'ownerEmailRef','')!~'^protected:[A-Z][A-Z0-9_]{2,95}$'or jsonb_typeof(p_request->'capabilities')<>'array'then raise exception using errcode='22023',message='invalid provisioning request';end if;
  v_hash:=encode(extensions.digest(convert_to(p_request::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_request->>'idempotencyKey',0));
  select*into v_run from public.erp_identity_provisioning_runs where idempotency_key=p_request->>'idempotencyKey'for update;
  if found then if v_run.manifest_sha256<>v_hash then raise exception using errcode='23505',message='idempotency conflict';end if;select tenant_id into v_tenant_id from public.erp_identity_provisioning_steps where run_id=v_run.id and action='create_tenant'limit 1;return jsonb_build_object('runId',v_run.id,'tenantId',v_tenant_id,'replayed',true,'status',v_run.status);end if;
  if exists(select 1 from public.tenants where slug=p_request->>'slug'or lower(dominio)=lower(p_request->>'domain'))or exists(select 1 from public.erp_establishments where cnpj=p_request->>'cnpj')then raise exception using errcode='23505',message='pilot identity already exists';end if;
  insert into public.erp_identity_provisioning_runs(idempotency_key,manifest_sha256,schema_version,environment,execution_mode,status,subject_count,started_at,summary)values(p_request->>'idempotencyKey',v_hash,1,'staging','apply','running',1,now(),jsonb_build_object('pilot',true,'identity_values_logged',false))returning*into v_run;
  insert into public.tenants(nome,slug,vertical,dominio)values(btrim(p_request->>'displayName'),p_request->>'slug',p_request->>'vertical',lower(p_request->>'domain'))returning id into v_tenant_id;
  insert into public.erp_establishments(tenant_id,code,kind,legal_name,trade_name,cnpj,state_registration)values(v_tenant_id,upper(p_request->>'establishmentCode'),'headquarters',btrim(p_request->>'legalName'),btrim(p_request->>'tradeName'),p_request->>'cnpj',p_request->>'stateRegistration')returning id into v_establishment_id;
  insert into public.erp_roles(tenant_id,key,name,description,is_system,requires_mfa,sensitivity)values(v_tenant_id,'owner','Proprietário','Responsável privilegiado do tenant.',true,true,'privileged')returning id into v_role_id;
  insert into public.erp_role_permissions(tenant_id,role_id,permission_id)select v_tenant_id,v_role_id,id from public.erp_permissions where active;
  for v_capability in select jsonb_array_elements_text(p_request->'capabilities')loop perform public.erp_set_tenant_capability(v_tenant_id,v_capability,'active','contract',1,encode(extensions.digest(convert_to(v_hash||':'||v_capability,'UTF8'),'sha256'),'hex'));end loop;
  insert into public.erp_identity_provisioning_steps(run_id,step_key,subject_key,action,status,tenant_id,finished_at)values
    (v_run.id,'m18.01:create_tenant',p_request->>'ownerSubjectKey','create_tenant','completed',v_tenant_id,now()),
    (v_run.id,'m18.02:create_establishment',p_request->>'ownerSubjectKey','create_establishment','completed',v_tenant_id,now()),
    (v_run.id,'m18.03:assign_capabilities',p_request->>'ownerSubjectKey','assign_capabilities','completed',v_tenant_id,now()),
    (v_run.id,'m18.04:enqueue_auth_invitation',p_request->>'ownerSubjectKey','enqueue_auth_invitation','completed',v_tenant_id,now()),
    (v_run.id,'m18.05:finalize_identity',p_request->>'ownerSubjectKey','finalize_identity','planned',v_tenant_id,null),
    (v_run.id,'m18.06:require_mfa',p_request->>'ownerSubjectKey','require_mfa','planned',v_tenant_id,null);
  insert into public.erp_auth_invitation_outbox(run_id,tenant_id,subject_key,email_ref,payload_hash)values(v_run.id,v_tenant_id,p_request->>'ownerSubjectKey',p_request->>'ownerEmailRef',v_hash)returning id into v_outbox_id;
  return jsonb_build_object('runId',v_run.id,'tenantId',v_tenant_id,'establishmentId',v_establishment_id,'outboxId',v_outbox_id,'replayed',false,'status','awaiting_auth_dispatch');
end$$;

create or replace function public.erp_record_pilot_auth_identity_v1(p_run_id uuid,p_auth_user_id uuid)returns jsonb
language plpgsql security definer set search_path=''as $$
declare v_outbox public.erp_auth_invitation_outbox%rowtype;
begin
  if auth.role()<>'service_role'then raise exception using errcode='42501',message='broker only';end if;
  if not exists(select 1 from auth.users where id=p_auth_user_id)or not exists(select 1 from public.users where id=p_auth_user_id)then raise exception using errcode='55000',message='auth identity not ready';end if;
  select*into v_outbox from public.erp_auth_invitation_outbox where run_id=p_run_id for update;if not found then raise exception 'outbox not found';end if;
  if v_outbox.status='identity_created'and v_outbox.auth_user_id=p_auth_user_id then return jsonb_build_object('runId',p_run_id,'userId',p_auth_user_id,'replayed',true);end if;
  if v_outbox.status not in('pending','processing')or(v_outbox.auth_user_id is not null and v_outbox.auth_user_id<>p_auth_user_id)then raise exception using errcode='55000',message='auth dispatch conflict';end if;
  update public.erp_auth_invitation_outbox set status='identity_created',auth_user_id=p_auth_user_id,attempt_count=attempt_count+1,lease_until=null,last_error_code=null where id=v_outbox.id;
  return jsonb_build_object('runId',p_run_id,'tenantId',v_outbox.tenant_id,'userId',p_auth_user_id,'replayed',false);
end$$;

create or replace function public.erp_finalize_pilot_identity_v1(p_run_id uuid,p_auth_user_id uuid)returns jsonb
language plpgsql security definer set search_path=''as $$
declare v_outbox public.erp_auth_invitation_outbox%rowtype;v_membership_id uuid;v_role_id uuid;
begin
  if auth.role()<>'service_role'then raise exception using errcode='42501',message='broker only';end if;
  select*into v_outbox from public.erp_auth_invitation_outbox where run_id=p_run_id for update;if not found then raise exception 'outbox not found';end if;
  if v_outbox.status='sent'and v_outbox.auth_user_id=p_auth_user_id then return jsonb_build_object('runId',p_run_id,'userId',p_auth_user_id,'replayed',true);end if;
  if v_outbox.status<>'identity_created'or v_outbox.auth_user_id<>p_auth_user_id or not exists(select 1 from auth.users where id=p_auth_user_id)or not exists(select 1 from public.users where id=p_auth_user_id)then raise exception using errcode='55000',message='auth identity not ready';end if;
  select id into strict v_role_id from public.erp_roles where tenant_id=v_outbox.tenant_id and key='owner'and requires_mfa and sensitivity='privileged';
  insert into public.erp_tenant_memberships(tenant_id,user_id,status,is_default,invited_at,invitation_expires_at)values(v_outbox.tenant_id,p_auth_user_id,'invited',false,now(),now()+interval'72 hours')on conflict(tenant_id,user_id)do update set status='invited',invited_at=excluded.invited_at,invitation_expires_at=excluded.invitation_expires_at,revoked_at=null returning id into v_membership_id;
  insert into public.erp_membership_roles(tenant_id,membership_id,role_id)values(v_outbox.tenant_id,v_membership_id,v_role_id)on conflict do nothing;
  update public.erp_auth_invitation_outbox set status='sent',auth_user_id=p_auth_user_id,lease_until=null,last_error_code=null where id=v_outbox.id;
  update public.erp_identity_provisioning_steps set status='completed',user_id=p_auth_user_id,started_at=coalesce(started_at,now()),finished_at=now()where run_id=p_run_id and action='finalize_identity';
  update public.erp_identity_provisioning_runs set status='completed',finished_at=now(),summary=summary||jsonb_build_object('auth_invitation','sent','mfa_required',true)where id=p_run_id;
  return jsonb_build_object('runId',p_run_id,'tenantId',v_outbox.tenant_id,'userId',p_auth_user_id,'membershipId',v_membership_id,'replayed',false,'mfaRequired',true);
end$$;

create or replace function public.erp_schedule_pilot_auth_compensation_v1(p_run_id uuid,p_reason_hash text)returns uuid
language plpgsql security definer set search_path=''as $$
declare v_outbox public.erp_auth_invitation_outbox%rowtype;v_id uuid;
begin
  if auth.role()<>'service_role'then raise exception using errcode='42501',message='broker only';end if;if p_reason_hash!~'^[a-f0-9]{64}$'then raise exception using errcode='22023',message='invalid reason hash';end if;
  select*into v_outbox from public.erp_auth_invitation_outbox where run_id=p_run_id for update;if not found or v_outbox.auth_user_id is null or v_outbox.status not in('identity_created','sent','compensation_required')then raise exception using errcode='55000',message='compensation unavailable';end if;
  insert into public.erp_auth_identity_compensations(run_id,outbox_id,tenant_id,auth_user_id,reason_hash)values(p_run_id,v_outbox.id,v_outbox.tenant_id,v_outbox.auth_user_id,p_reason_hash)on conflict(outbox_id)do update set reason_hash=excluded.reason_hash returning id into v_id;
  update public.erp_auth_invitation_outbox set status='compensation_required'where id=v_outbox.id;
  insert into public.erp_identity_provisioning_steps(run_id,step_key,subject_key,action,status,tenant_id,user_id)values(p_run_id,'m18.07:compensate_auth_identity',v_outbox.subject_key,'compensate_auth_identity','planned',v_outbox.tenant_id,v_outbox.auth_user_id)on conflict(run_id,step_key)do nothing;
  return v_id;
end$$;

revoke execute on function public.erp_prepare_pilot_provisioning_v1(jsonb),public.erp_record_pilot_auth_identity_v1(uuid,uuid),public.erp_finalize_pilot_identity_v1(uuid,uuid),public.erp_schedule_pilot_auth_compensation_v1(uuid,text)from public,anon,authenticated;
grant execute on function public.erp_prepare_pilot_provisioning_v1(jsonb),public.erp_record_pilot_auth_identity_v1(uuid,uuid),public.erp_finalize_pilot_identity_v1(uuid,uuid),public.erp_schedule_pilot_auth_compensation_v1(uuid,text)to service_role;

commit;
