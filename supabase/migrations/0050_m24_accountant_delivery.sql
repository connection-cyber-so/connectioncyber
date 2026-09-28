-- M24-G0: pacote fiscal mensal ao contador - substitui o envio manual via AnyDesk.
-- Publicacao idempotente por competencia com manifesto canonico (SHA-256 calculado no
-- servidor a partir dos caminhos/hash dos arquivos, ordenados e sem depender da ordem
-- do cliente), recibo de confirmacao do contador, papel 'contador' SEM select direto
-- (leitura cross-tenant somente pela RPC auditada em logs_access, modo quebra-vidro do
-- Parecer tecnico #001 secao 05) e bucket privado fiscal-deliveries com restrictive
-- policies. Apply only after preflight and local/static validation.
begin;

create extension if not exists pgcrypto with schema extensions;

-- 1) Papel contador + helper (mesmo molde de is_platform_staff, mas so para leitura
--    auditada de pacotes fiscais; nada de escrita cross-tenant nas tabelas).
insert into public.roles(nome,descricao) values
 ('contador','Contador - leitura cross-tenant de pacotes fiscais, auditada em logs_access')
 on conflict (nome) do nothing;

create or replace function public.is_accountant()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    where ur.user_id = auth.uid() and r.nome = 'contador'
  )
$$;
comment on function public.is_accountant() is
 'Papel contador (escritorio contabil) - visao cross-tenant de pacotes fiscais sempre via RPC auditada; nunca select direto.';
revoke all on function public.is_accountant() from public,anon;
grant execute on function public.is_accountant() to authenticated,service_role;

-- 2) Tabelas
create table public.erp_accountant_packages(
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 competencia date not null check(extract(day from competencia)=1),
 status text not null default 'ready' check(status in('ready','acknowledged','void')),
 content_hash text not null check(content_hash~'^[a-f0-9]{64}$'),
 file_count integer not null check(file_count between 1 and 500),
 total_bytes bigint not null check(total_bytes between 1 and 524288000),
 acknowledged_at timestamptz,
 acknowledged_note text check(acknowledged_note is null or length(btrim(acknowledged_note)) between 1 and 2000),
 idempotency_key text not null check(length(idempotency_key) between 8 and 200),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(tenant_id,competencia),
 unique(tenant_id,idempotency_key),
 unique(tenant_id,id),
 check(acknowledged_at is null or status='acknowledged')
);
create index idx_accountant_packages_competencia on public.erp_accountant_packages(competencia desc);

create table public.erp_accountant_package_files(
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null,
 package_id uuid not null,
 storage_path text not null
   check(storage_path!~*'(https?://[^ ]+@|password|senha|token|secret|pfx|csc)' and storage_path not like '%..%' and storage_path like '%/%'),
 file_name text not null check(file_name ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,150}$' and file_name !~ '\.\.'),
 content_hash text not null check(content_hash~'^[a-f0-9]{64}$'),
 byte_size bigint not null check(byte_size between 1 and 10485760),
 kind text not null check(kind in('xml','danfe')),
 document_id uuid,
 created_at timestamptz not null default now(),
 foreign key(tenant_id,package_id) references public.erp_accountant_packages(tenant_id,id) on delete cascade,
 foreign key(tenant_id,document_id) references public.erp_fiscal_documents(tenant_id,id) on delete set null,
 unique(tenant_id,package_id,storage_path),
 unique(tenant_id,id)
);

create table public.erp_accountant_delivery_events(
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 package_id uuid not null,
 event_type text not null check(event_type in('published','acknowledged','voided')),
 note text check(note is null or length(btrim(note)) between 1 and 2000),
 actor uuid references auth.users(id),
 idempotency_key text not null check(length(idempotency_key) between 8 and 200),
 created_at timestamptz not null default now(),
 foreign key(tenant_id,package_id) references public.erp_accountant_packages(tenant_id,id) on delete cascade,
 unique(tenant_id,idempotency_key),
 unique(tenant_id,id)
);

-- 3) RLS: dono da empresa e equipe por select direto; escrita NUNCA direta (só RPC).
alter table public.erp_accountant_packages enable row level security;
alter table public.erp_accountant_package_files enable row level security;
alter table public.erp_accountant_delivery_events enable row level security;

create policy accountant_packages_read on public.erp_accountant_packages for select to authenticated
 using (tenant_id = public.current_tenant_id() or public.is_platform_staff());
create policy accountant_files_read on public.erp_accountant_package_files for select to authenticated
 using (tenant_id = public.current_tenant_id() or public.is_platform_staff());
create policy accountant_events_read on public.erp_accountant_delivery_events for select to authenticated
 using (tenant_id = public.current_tenant_id() or public.is_platform_staff());

revoke all on public.erp_accountant_packages,public.erp_accountant_package_files,public.erp_accountant_delivery_events from anon;
revoke insert,update,delete on public.erp_accountant_packages,public.erp_accountant_package_files,public.erp_accountant_delivery_events from authenticated;
grant select on public.erp_accountant_packages,public.erp_accountant_package_files,public.erp_accountant_delivery_events to authenticated;

-- 4) Permissao do dono para publicar/anular pacotes
insert into public.erp_permissions(key,name,description,category)
 values('fiscal.deliver','Preparar pacote ao contador','Publica e anula pacotes fiscais mensais destinados ao contador.','Fiscal')
 on conflict(key) do update set name=excluded.name,description=excluded.description,active=true;

-- 5) RPCs
create or replace function public.erp_publish_accountant_package(
 p_tenant_id uuid, p_competencia date, p_files jsonb, p_idempotency_key text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
 v_pkg uuid; v_existing uuid; v_prefix text; v_lines text[] := '{}';
 f jsonb; v_path text; v_sha text; v_bytes bigint; v_kind text; v_doc uuid;
 v_hash text; v_total bigint := 0; v_count integer := 0; v_now timestamptz := now();
begin
 if not (erp_security.has_permission(p_tenant_id,'fiscal.deliver') or public.is_platform_staff()) then
  raise exception 'permission denied';
 end if;
 if p_competencia is null or extract(day from p_competencia) <> 1 or p_competencia > date_trunc('month',v_now)::date then
  raise exception 'invalid competencia';
 end if;
 if length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key'; end if;
 if jsonb_typeof(p_files) <> 'array' or jsonb_array_length(p_files) < 1 or jsonb_array_length(p_files) > 500 then
  raise exception 'invalid files';
 end if;
 select id into v_existing from public.erp_accountant_packages
  where tenant_id = p_tenant_id and idempotency_key = p_idempotency_key;
 if v_existing is not null then return v_existing; end if;
 if exists(select 1 from public.erp_accountant_packages
           where tenant_id = p_tenant_id and competencia = p_competencia and status <> 'void') then
  raise exception 'competencia already published';
 end if;
 v_prefix := p_tenant_id::text || '/' || to_char(p_competencia,'YYYY-MM') || '/';
 for f in select value from jsonb_array_elements(p_files)
 loop
  v_path := f->>'storage_path'; v_sha := f->>'content_hash';
  v_bytes := nullif(f->>'byte_size','')::bigint; v_kind := f->>'kind';
  v_doc := nullif(f->>'document_id','');
  if coalesce(v_path,'') = '' or left(v_path,length(v_prefix)) <> v_prefix then
   raise exception 'invalid storage path';
  end if;
  if position('/' in substring(v_path from length(v_prefix)+1)) > 0 then raise exception 'nested storage path'; end if;
  if substring(v_path from length(v_prefix)+1) <> coalesce(f->>'file_name','') then raise exception 'file name mismatch'; end if;
  if coalesce(f->>'file_name','') !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,150}$' or coalesce(f->>'file_name','') ~ '\.\.' then
   raise exception 'invalid file name';
  end if;
  if v_sha is null or v_sha !~ '^[a-f0-9]{64}$' then raise exception 'invalid content hash'; end if;
  if v_bytes is null or v_bytes < 1 or v_bytes > 10485760 then raise exception 'invalid byte size'; end if;
  if v_kind not in ('xml','danfe') then raise exception 'invalid kind'; end if;
  if (v_kind = 'xml' and coalesce(f->>'file_name','') !~* '\.xml$')
  or (v_kind = 'danfe' and coalesce(f->>'file_name','') !~* '\.pdf$') then
   raise exception 'kind and extension mismatch';
  end if;
  if v_doc is not null and not exists(select 1 from public.erp_fiscal_documents d
                                      where d.tenant_id = p_tenant_id and d.id = v_doc) then
   raise exception 'invalid document';
  end if;
  v_lines := array_append(v_lines, v_sha || ' ' || v_path);
  v_total := v_total + v_bytes;
  v_count := v_count + 1;
 end loop;
 -- Manifesto canonico: linhas ordenadas (independente da ordem enviada pelo cliente).
 select encode(extensions.digest(string_agg(l, E'\n' order by l) || E'\n', 'sha256'), 'hex')
  into v_hash from unnest(v_lines) as t(l);
 insert into public.erp_accountant_packages
   (tenant_id,competencia,status,content_hash,file_count,total_bytes,idempotency_key,created_by,created_at,updated_at)
  values (p_tenant_id,p_competencia,'ready',v_hash,v_count,v_total,p_idempotency_key,auth.uid(),v_now,v_now)
  returning id into v_pkg;
 insert into public.erp_accountant_package_files
   (tenant_id,package_id,storage_path,file_name,content_hash,byte_size,kind,document_id)
  select p_tenant_id, v_pkg, value->>'storage_path', value->>'file_name', value->>'content_hash',
         (value->>'byte_size')::bigint, value->>'kind', nullif(value->>'document_id','')::uuid
  from jsonb_array_elements(p_files);
 insert into public.erp_accountant_delivery_events
   (tenant_id,package_id,event_type,actor,idempotency_key)
  values (p_tenant_id, v_pkg, 'published', auth.uid(), p_idempotency_key || ':event');
 return v_pkg;
end $$;
revoke all on function public.erp_publish_accountant_package(uuid,date,jsonb,text) from public,anon;
grant execute on function public.erp_publish_accountant_package(uuid,date,jsonb,text) to authenticated,service_role;

-- Leitura do contador: cross-tenant SEM select direto - uma chamada = um log em
-- logs_access (quebra-vidro), packages + files embutidos no mesmo resultado.
create or replace function public.erp_list_accountant_packages(p_tenant_id uuid, p_limit integer)
returns table (pkg jsonb, files jsonb)
language plpgsql security definer set search_path = '' as $$
declare v_limit integer := coalesce(p_limit, 60);
begin
 if not (public.is_accountant() or public.is_platform_staff()) then raise exception 'permission denied'; end if;
 if v_limit < 1 or v_limit > 200 then v_limit := 60; end if;
 insert into public.logs_access(user_id,rota,tenant_id)
  values (auth.uid(), 'rpc:erp_list_accountant_packages', p_tenant_id);
 return query
  select to_jsonb(p.*),
         coalesce((select jsonb_agg(to_jsonb(f.*) order by f.file_name)
                   from public.erp_accountant_package_files f where f.package_id = p.id), '[]'::jsonb)
  from public.erp_accountant_packages p
  where (p_tenant_id is null or p.tenant_id = p_tenant_id)
  order by p.competencia desc, p.created_at desc
  limit v_limit;
end $$;
revoke all on function public.erp_list_accountant_packages(uuid,integer) from public,anon;
grant execute on function public.erp_list_accountant_packages(uuid,integer) to authenticated,service_role;

create or replace function public.erp_ack_accountant_package(
 p_tenant_id uuid, p_package_id uuid, p_note text, p_idempotency_key text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_status text; v_exists uuid;
begin
 if not (public.is_accountant() or public.is_platform_staff()) then raise exception 'permission denied'; end if;
 if length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key'; end if;
 if p_note is not null and length(btrim(p_note)) not between 1 and 2000 then raise exception 'invalid note'; end if;
 select package_id into v_exists from public.erp_accountant_delivery_events
  where tenant_id = p_tenant_id and idempotency_key = p_idempotency_key;
 if v_exists is not null then return p_package_id; end if;
 select status into v_status from public.erp_accountant_packages
  where tenant_id = p_tenant_id and id = p_package_id for update;
 if not found then raise exception 'package not found'; end if;
 if v_status = 'void' then raise exception 'void package'; end if;
 if v_status = 'acknowledged' then raise exception 'already acknowledged'; end if;
 update public.erp_accountant_packages
  set status = 'acknowledged', acknowledged_at = now(), acknowledged_note = p_note, updated_at = now()
  where tenant_id = p_tenant_id and id = p_package_id;
 insert into public.erp_accountant_delivery_events
   (tenant_id,package_id,event_type,note,actor,idempotency_key)
  values (p_tenant_id,p_package_id,'acknowledged',p_note,auth.uid(),p_idempotency_key);
 insert into public.logs_access(user_id,rota,tenant_id)
  values (auth.uid(), 'rpc:erp_ack_accountant_package', p_tenant_id);
 return p_package_id;
end $$;
revoke all on function public.erp_ack_accountant_package(uuid,uuid,text,text) from public,anon;
grant execute on function public.erp_ack_accountant_package(uuid,uuid,text,text) to authenticated,service_role;

create or replace function public.erp_void_accountant_package(
 p_tenant_id uuid, p_package_id uuid, p_reason text, p_idempotency_key text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_status text; v_exists uuid;
begin
 if not (erp_security.has_permission(p_tenant_id,'fiscal.deliver') or public.is_platform_staff()) then
  raise exception 'permission denied';
 end if;
 if length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key'; end if;
 if p_reason is null or length(btrim(p_reason)) not between 1 and 1000 then raise exception 'invalid reason'; end if;
 select package_id into v_exists from public.erp_accountant_delivery_events
  where tenant_id = p_tenant_id and idempotency_key = p_idempotency_key;
 if v_exists is not null then return p_package_id; end if;
 select status into v_status from public.erp_accountant_packages
  where tenant_id = p_tenant_id and id = p_package_id for update;
 if not found then raise exception 'package not found'; end if;
 if v_status = 'void' then raise exception 'already void'; end if;
 -- Anula limpa o recibo (historico permanece em erp_accountant_delivery_events).
 update public.erp_accountant_packages
  set status = 'void', acknowledged_at = null, acknowledged_note = null, updated_at = now()
  where tenant_id = p_tenant_id and id = p_package_id;
 insert into public.erp_accountant_delivery_events
   (tenant_id,package_id,event_type,note,actor,idempotency_key)
  values (p_tenant_id,p_package_id,'voided',p_reason,auth.uid(),p_idempotency_key);
 insert into public.logs_access(user_id,rota,tenant_id)
  values (auth.uid(), 'rpc:erp_void_accountant_package', p_tenant_id);
 return p_package_id;
end $$;
revoke all on function public.erp_void_accountant_package(uuid,uuid,text,text) from public,anon;
grant execute on function public.erp_void_accountant_package(uuid,uuid,text,text) to authenticated,service_role;

-- Trilha de download: a pagina que gera signed URLs registra a exportacao no mesmo
-- padrao quebra-vidro (contagem de arquivos, sem conteudo).
create or replace function public.erp_log_accountant_download(
 p_tenant_id uuid, p_package_id uuid, p_file_count integer)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not (public.is_accountant() or public.is_platform_staff()
         or erp_security.has_permission(p_tenant_id,'fiscal.deliver')) then
  raise exception 'permission denied';
 end if;
 if p_file_count is null or p_file_count < 1 or p_file_count > 500 then raise exception 'invalid file count'; end if;
 if not exists(select 1 from public.erp_accountant_packages where tenant_id = p_tenant_id and id = p_package_id) then
  raise exception 'package not found';
 end if;
 insert into public.logs_access(user_id,rota,tenant_id)
  values (auth.uid(), 'rpc:erp_log_accountant_download:files=' || p_file_count, p_tenant_id);
end $$;
revoke all on function public.erp_log_accountant_download(uuid,uuid,integer) from public,anon;
grant execute on function public.erp_log_accountant_download(uuid,uuid,integer) to authenticated,service_role;

-- 6) Bucket privado + policies (molde da 0043 kb_storage_*).
insert into storage.buckets(id,name,public,file_size_limit)
 values('fiscal-deliveries','fiscal-deliveries',false,10485760)
 on conflict (id) do update set public=false, file_size_limit=excluded.file_size_limit;

create policy fd_storage_insert on storage.objects for insert to authenticated with check (
 bucket_id = 'fiscal-deliveries'
 and split_part(name,'/',1) = public.current_tenant_id()::text
 and position('/' in substring(name from length(public.current_tenant_id()::text)+2)) > 0
 and erp_security.is_tenant_member(public.current_tenant_id()));

create policy fd_storage_select on storage.objects for select to authenticated using (
 bucket_id = 'fiscal-deliveries'
 and (split_part(name,'/',1) = public.current_tenant_id()::text
      or public.is_accountant() or public.is_platform_staff()));

-- Restrictive policies also protect this bucket from unrelated permissive policies.
create policy fd_storage_no_update on storage.objects as restrictive for update to authenticated
 using (bucket_id <> 'fiscal-deliveries') with check (bucket_id <> 'fiscal-deliveries');
create policy fd_storage_no_delete on storage.objects as restrictive for delete to authenticated
 using (bucket_id <> 'fiscal-deliveries');
create policy fd_storage_anon_guard on storage.objects as restrictive for all to anon
 using (bucket_id <> 'fiscal-deliveries') with check (bucket_id <> 'fiscal-deliveries');

commit;
