-- ConnectionCyber — M12: agente local, periféricos e contingência.
begin;

create table public.erp_agent_installations(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,establishment_id uuid not null,
  code text not null,name text not null,status text not null default 'pairing'check(status in('pairing','active','suspended','revoked')),
  key_id text,public_key_pem text,protocol_version text not null default '1.0',agent_version text,last_seen_at timestamptz,paired_at timestamptz,revoked_at timestamptz,
  created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(tenant_id,code),unique(tenant_id,id),unique(tenant_id,key_id),
  foreign key(tenant_id,establishment_id)references public.erp_establishments(tenant_id,id)on delete restrict,
  check((status='pairing'and key_id is null and public_key_pem is null)or(status<>'pairing'and key_id is not null and public_key_pem is not null)),
  check(public_key_pem is null or(public_key_pem like '-----BEGIN PUBLIC KEY-----%'and length(public_key_pem)<=2000))
);
create table public.erp_agent_pairings(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,agent_id uuid not null,
  code_hash text not null check(code_hash~'^[a-f0-9]{64}$'),status text not null default 'pending'check(status in('pending','consumed','expired','revoked')),
  expires_at timestamptz not null,consumed_at timestamptz,created_by uuid references auth.users(id),created_at timestamptz not null default now(),
  unique(tenant_id,code_hash),unique(tenant_id,id),foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete cascade,check(expires_at>created_at)
);
create table public.erp_agent_peripherals(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,agent_id uuid not null,
  logical_code text not null,kind text not null check(kind in('printer','label_printer','scale','cash_drawer','customer_display','tef')),
  adapter text not null,status text not null default 'discovered'check(status in('discovered','configured','online','offline','disabled')),
  capabilities jsonb not null default '{}'::jsonb,configuration jsonb not null default '{}'::jsonb,configuration_hash text check(configuration_hash is null or configuration_hash~'^[a-f0-9]{64}$'),
  last_seen_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(tenant_id,agent_id,logical_code),unique(tenant_id,id),
  foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete cascade,
  check(jsonb_typeof(capabilities)='object'and jsonb_typeof(configuration)='object'),check(configuration::text!~*'"(password|token|secret|credential|private_key|service_role|certificate)"[[:space:]]*:')
);
create table public.erp_agent_commands(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,agent_id uuid not null,peripheral_id uuid,
  message_id uuid not null,type text not null check(type in('print.execute','scale.read','cash_drawer.open','tef.execute','offline.snapshot.ack')),
  protocol_version text not null default '1.0',payload jsonb not null,document_hash text,nonce_hash text not null check(nonce_hash~'^[a-f0-9]{64}$'),
  idempotency_key text not null,status text not null default 'queued'check(status in('queued','delivered','acknowledged','executing','succeeded','failed','expired','cancelled')),
  issued_at timestamptz not null default now(),expires_at timestamptz not null,result_code text,completed_at timestamptz,created_by uuid references auth.users(id),created_at timestamptz not null default now(),
  unique(tenant_id,message_id),unique(tenant_id,idempotency_key),unique(tenant_id,nonce_hash),unique(tenant_id,id),
  foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete restrict,foreign key(tenant_id,peripheral_id)references public.erp_agent_peripherals(tenant_id,id)on delete restrict,
  check(expires_at>issued_at and expires_at<=issued_at+interval '5 minutes'),check(jsonb_typeof(payload)='object'),check(payload::text!~*'"(password|access_token|refresh_token|service_role|private_key|cvv|full_pan|pin_block|secret|credential)"[[:space:]]*:')
);
create table public.erp_agent_command_attempts(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,command_id uuid not null,attempt integer not null check(attempt>0),
  status text not null check(status in('delivered','acknowledged','executing','succeeded','failed','expired')),error_code text,error_detail text,started_at timestamptz not null default now(),finished_at timestamptz,
  unique(tenant_id,command_id,attempt),unique(tenant_id,id),foreign key(tenant_id,command_id)references public.erp_agent_commands(tenant_id,id)on delete cascade,
  check(error_detail is null or error_detail!~*'(password|token|secret|credential|private.key|cvv)')
);
create table public.erp_agent_events(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,agent_id uuid not null,event_type text not null,
  detail jsonb not null default '{}'::jsonb,idempotency_key text not null,created_at timestamptz not null default now(),unique(tenant_id,idempotency_key),unique(tenant_id,id),
  foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete restrict,
  check(detail::text!~*'"(password|token|secret|credential|private_key|service_role|certificate|cvv)"[[:space:]]*:')
);
create table public.erp_offline_snapshots(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,establishment_id uuid not null,agent_id uuid not null,
  version bigint not null check(version>0),content_hash text not null check(content_hash~'^[a-f0-9]{64}$'),status text not null default 'prepared'check(status in('prepared','available','acknowledged','expired','revoked')),
  valid_from timestamptz not null,expires_at timestamptz not null,acknowledged_at timestamptz,created_at timestamptz not null default now(),unique(tenant_id,establishment_id,version),unique(tenant_id,id),
  foreign key(tenant_id,establishment_id)references public.erp_establishments(tenant_id,id)on delete restrict,foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete restrict,
  check(expires_at>valid_from and expires_at<=valid_from+interval '24 hours')
);
create table public.erp_offline_sequence_reservations(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,establishment_id uuid not null,agent_id uuid not null,
  sequence_key text not null,range_start bigint not null,range_end bigint not null,next_value bigint not null,status text not null default 'active'check(status in('active','exhausted','expired','revoked')),
  expires_at timestamptz not null,created_at timestamptz not null default now(),unique(tenant_id,sequence_key,range_start,range_end),unique(tenant_id,id),
  foreign key(tenant_id,establishment_id)references public.erp_establishments(tenant_id,id)on delete restrict,foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete restrict,
  check(range_start>0 and range_end>=range_start and next_value between range_start and range_end+1)
);
create table public.erp_offline_operations(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,establishment_id uuid not null,agent_id uuid not null,snapshot_id uuid not null,
  operation_id uuid not null,operation_type text not null,sequence bigint not null check(sequence>0),previous_hash text,operation_hash text not null check(operation_hash~'^[a-f0-9]{64}$'),
  payload jsonb not null,status text not null default 'local_pending'check(status in('local_pending','syncing','accepted','rejected','manual_review')),
  occurred_at timestamptz not null,received_at timestamptz not null default now(),resolved_at timestamptz,resolution_reason text,
  unique(tenant_id,operation_id),unique(tenant_id,agent_id,sequence),unique(tenant_id,agent_id,operation_hash),unique(tenant_id,id),
  foreign key(tenant_id,establishment_id)references public.erp_establishments(tenant_id,id)on delete restrict,foreign key(tenant_id,agent_id)references public.erp_agent_installations(tenant_id,id)on delete restrict,foreign key(tenant_id,snapshot_id)references public.erp_offline_snapshots(tenant_id,id)on delete restrict,
  check(previous_hash is null or previous_hash~'^[a-f0-9]{64}$'),check(jsonb_typeof(payload)='object'),check(payload::text!~*'"(password|token|secret|credential|private_key|service_role|certificate|cvv|full_pan)"[[:space:]]*:')
);
create table public.erp_offline_sync_conflicts(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,operation_id uuid not null,kind text not null,
  detail jsonb not null default '{}'::jsonb,status text not null default 'open'check(status in('open','resolved','dismissed')),resolved_by uuid references auth.users(id),resolved_at timestamptz,created_at timestamptz not null default now(),
  unique(tenant_id,operation_id,kind),unique(tenant_id,id),foreign key(tenant_id,operation_id)references public.erp_offline_operations(tenant_id,id)on delete restrict,
  check(detail::text!~*'"(password|token|secret|credential|private_key|service_role|certificate|cvv)"[[:space:]]*:')
);
create table public.erp_agent_versions(
  id uuid primary key default gen_random_uuid(),version text not null unique,channel text not null check(channel in('stable','pilot','blocked')),artifact_hash text not null check(artifact_hash~'^[a-f0-9]{64}$'),
  signature text not null,min_protocol_version text not null,released_at timestamptz not null,blocked_at timestamptz,created_at timestamptz not null default now()
);
create table public.erp_agent_update_policies(
  id uuid primary key default gen_random_uuid(),tenant_id uuid not null references public.tenants(id)on delete cascade,establishment_id uuid,channel text not null default 'stable'check(channel in('stable','pilot')),
  minimum_version text,automatic boolean not null default false,maintenance_window jsonb not null default '{}'::jsonb,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
  unique(tenant_id,establishment_id),unique(tenant_id,id),foreign key(tenant_id,establishment_id)references public.erp_establishments(tenant_id,id)on delete cascade,
  check(jsonb_typeof(maintenance_window)='object')
);

insert into public.erp_permissions(key,name,description,category)values
('agent.read','Consultar agentes','Consulta agentes e periféricos do tenant.','Agente local'),
('agent.manage','Gerenciar agentes','Pareia, suspende e revoga agentes.','Agente local'),
('peripheral.manage','Gerenciar periféricos','Configura periféricos e comandos locais.','Agente local'),
('offline.sync','Sincronizar contingência','Processa operações e conflitos offline.','Agente local'),
('agent.audit','Auditar agentes','Consulta comandos, tentativas e eventos.','Agente local')
on conflict(key)do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;

create or replace function public.erp_create_agent_pairing(p_tenant_id uuid,p_agent_id uuid,p_idempotency_key text)returns table(pairing_id uuid,pairing_code text)language plpgsql security definer set search_path=''as $$declare v_id uuid;v_code text;begin if erp_security.current_aal()<>'aal2'or not(erp_security.has_permission(p_tenant_id,'agent.manage')or public.is_platform_staff())then raise exception 'permission and aal2 required';end if;if length(btrim(p_idempotency_key))not between 8 and 200 then raise exception 'invalid idempotency key';end if;if not exists(select 1 from public.erp_agent_installations where tenant_id=p_tenant_id and id=p_agent_id and status='pairing')then raise exception 'agent not eligible';end if;perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||p_agent_id::text,0));select id into v_id from public.erp_agent_pairings where tenant_id=p_tenant_id and agent_id=p_agent_id and status='pending'and expires_at>now();if v_id is not null then return query select v_id,null::text;return;end if;v_code:=upper(encode(gen_random_bytes(9),'hex'));insert into public.erp_agent_pairings(tenant_id,agent_id,code_hash,expires_at,created_by)values(p_tenant_id,p_agent_id,encode(digest(v_code,'sha256'),'hex'),now()+interval '10 minutes',auth.uid())returning id into v_id;insert into public.erp_agent_events(tenant_id,agent_id,event_type,detail,idempotency_key)values(p_tenant_id,p_agent_id,'pairing_created','{}',p_idempotency_key);return query select v_id,v_code;end$$;
create or replace function public.erp_revoke_agent(p_tenant_id uuid,p_agent_id uuid,p_reason text,p_idempotency_key text)returns uuid language plpgsql security definer set search_path=''as $$begin if erp_security.current_aal()<>'aal2'or not(erp_security.has_permission(p_tenant_id,'agent.manage')or public.is_platform_staff())then raise exception 'permission and aal2 required';end if;if length(btrim(p_reason))not between 1 and 1000 then raise exception 'reason required';end if;perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text||':'||p_agent_id::text,0));update public.erp_agent_installations set status='revoked',revoked_at=coalesce(revoked_at,now()),updated_at=now()where tenant_id=p_tenant_id and id=p_agent_id and status<>'revoked';if not found and not exists(select 1 from public.erp_agent_installations where tenant_id=p_tenant_id and id=p_agent_id and status='revoked')then raise exception 'agent not found';end if;update public.erp_agent_commands set status='cancelled',completed_at=now(),result_code='agent_revoked'where tenant_id=p_tenant_id and agent_id=p_agent_id and status in('queued','delivered','acknowledged','executing');insert into public.erp_agent_events(tenant_id,agent_id,event_type,detail,idempotency_key)values(p_tenant_id,p_agent_id,'agent_revoked',jsonb_build_object('reason',btrim(p_reason)),p_idempotency_key)on conflict(tenant_id,idempotency_key)do nothing;return p_agent_id;end$$;
create or replace function public.erp_queue_agent_command(p_tenant_id uuid,p_agent_id uuid,p_peripheral_id uuid,p_type text,p_payload jsonb,p_document_hash text,p_nonce_hash text,p_idempotency_key text)returns uuid language plpgsql security definer set search_path=''as $$declare v_id uuid;begin if erp_security.current_aal()<>'aal2'or not(erp_security.has_permission(p_tenant_id,'peripheral.manage')or public.is_platform_staff())then raise exception 'permission and aal2 required';end if;if p_type not in('print.execute','scale.read','cash_drawer.open','tef.execute','offline.snapshot.ack')or jsonb_typeof(p_payload)<>'object'then raise exception 'invalid command';end if;if p_payload::text~*'"(password|access_token|refresh_token|service_role|private_key|cvv|full_pan|pin_block|secret|credential)"[[:space:]]*:'then raise exception 'secret field forbidden';end if;if p_nonce_hash!~'^[a-f0-9]{64}$'or length(btrim(p_idempotency_key))not between 8 and 200 then raise exception 'invalid nonce or idempotency key';end if;select id into v_id from public.erp_agent_commands where tenant_id=p_tenant_id and idempotency_key=p_idempotency_key;if v_id is not null then return v_id;end if;if not exists(select 1 from public.erp_agent_installations where tenant_id=p_tenant_id and id=p_agent_id and status='active')then raise exception 'agent not active';end if;if p_peripheral_id is not null and not exists(select 1 from public.erp_agent_peripherals where tenant_id=p_tenant_id and id=p_peripheral_id and agent_id=p_agent_id and status in('configured','online'))then raise exception 'peripheral not eligible';end if;insert into public.erp_agent_commands(tenant_id,agent_id,peripheral_id,message_id,type,payload,document_hash,nonce_hash,idempotency_key,expires_at,created_by)values(p_tenant_id,p_agent_id,p_peripheral_id,gen_random_uuid(),p_type,p_payload,p_document_hash,p_nonce_hash,p_idempotency_key,now()+interval '5 minutes',auth.uid())returning id into v_id;return v_id;end$$;
create or replace function public.erp_resolve_offline_operation(p_tenant_id uuid,p_operation_id uuid,p_status text,p_reason text)returns uuid language plpgsql security definer set search_path=''as $$declare v_id uuid;begin if not(erp_security.has_permission(p_tenant_id,'offline.sync')or public.is_platform_staff())then raise exception 'permission denied';end if;if p_status not in('accepted','rejected','manual_review')then raise exception 'invalid status';end if;update public.erp_offline_operations set status=p_status,resolution_reason=nullif(btrim(p_reason),''),resolved_at=now()where tenant_id=p_tenant_id and operation_id=p_operation_id and status in('local_pending','syncing')returning id into v_id;if v_id is null then raise exception 'operation not pending';end if;return v_id;end$$;

do $$declare t text;begin foreach t in array array['erp_agent_installations','erp_agent_pairings','erp_agent_peripherals','erp_agent_commands','erp_agent_command_attempts','erp_agent_events','erp_offline_snapshots','erp_offline_sequence_reservations','erp_offline_operations','erp_offline_sync_conflicts','erp_agent_update_policies']loop execute format('alter table public.%I enable row level security',t);execute format('create policy %I on public.%I for select to authenticated using (erp_security.has_permission(tenant_id,''agent.read'')or erp_security.has_permission(tenant_id,''agent.audit'')or public.is_platform_staff())',t||'_select',t);execute format('revoke all on table public.%I from anon,authenticated',t);execute format('grant select on table public.%I to authenticated',t);execute format('grant all on table public.%I to service_role',t);end loop;end$$;
alter table public.erp_agent_versions enable row level security;create policy erp_agent_versions_select on public.erp_agent_versions for select to authenticated using(true);revoke all on public.erp_agent_versions from anon,authenticated;grant select on public.erp_agent_versions to authenticated;grant all on public.erp_agent_versions to service_role;
revoke execute on function public.erp_create_agent_pairing(uuid,uuid,text),public.erp_revoke_agent(uuid,uuid,text,text),public.erp_queue_agent_command(uuid,uuid,uuid,text,jsonb,text,text,text),public.erp_resolve_offline_operation(uuid,uuid,text,text)from public,anon;
grant execute on function public.erp_create_agent_pairing(uuid,uuid,text),public.erp_revoke_agent(uuid,uuid,text,text),public.erp_queue_agent_command(uuid,uuid,uuid,text,jsonb,text,text,text),public.erp_resolve_offline_operation(uuid,uuid,text,text)to authenticated,service_role;
commit;
