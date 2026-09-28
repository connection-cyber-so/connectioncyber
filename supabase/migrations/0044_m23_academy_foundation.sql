-- M23 0.1.0: additive; apply only after preflight and local/static validation.
begin;
insert into public.erp_capability_catalog(key,name,description,category,risk_level) values
 ('academy.courses','Portal de Cursos','Catalogo de cursos, matriculas, trilhas e progresso por tenant.','academy','standard')
 on conflict(key) do update set name=excluded.name,description=excluded.description,category=excluded.category,risk_level=excluded.risk_level,active=true;
insert into public.erp_permissions(key,name,description,category) values
 ('academy.read','Consultar Academia','Consulta catalogo, matriculas e progresso do tenant.','academy'),
 ('academy.manage','Gerenciar Academia','Cria, edita e publica cursos e modulos do tenant.','academy')
 on conflict(key) do update set name=excluded.name,description=excluded.description,category=excluded.category,active=true;
create table public.academy_courses (
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 titulo text not null check(length(titulo) between 3 and 180),
 descricao text not null default '' check(length(descricao)<=5000),
 categoria text not null default 'Geral' check(length(categoria) between 1 and 80),
 idioma text not null default 'pt-BR' check(idioma in ('pt-BR','es-419','en-US')),
 nivel text not null default 'iniciante' check(nivel in ('iniciante','intermediario','avancado')),
 capa_url text not null default '' check(capa_url='' or capa_url ~ '^https://[^[:space:]]+$'),
 status text not null default 'rascunho' check(status in ('rascunho','publicado','arquivado')),
 duracao_min integer not null default 0 check(duracao_min between 0 and 100000),
 preco numeric(10,2) not null default 0 check(preco>=0),
 ordem integer not null default 0 check(ordem>=0),
 publicado_em timestamptz,
 created_by uuid references public.users(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(tenant_id,id)
);
create index academy_courses_catalog on public.academy_courses(tenant_id,status,ordem,id);
create table public.academy_modules (
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 course_id uuid not null,
 titulo text not null check(length(titulo) between 3 and 180),
 tipo text not null default 'video' check(tipo in ('video','texto','pdf','quiz','prova')),
 conteudo_ref text not null default '' check(conteudo_ref='' or conteudo_ref ~ '^(https://|academy:)'),
 duracao_min integer not null default 0 check(duracao_min between 0 and 10000),
 ordem integer not null default 0 check(ordem>=0),
 obrigatorio boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(tenant_id,id),
 foreign key(tenant_id,course_id) references public.academy_courses(tenant_id,id) on delete cascade
);
create unique index academy_modules_course_order on public.academy_modules(tenant_id,course_id,ordem);
create table public.academy_enrollments (
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 user_id uuid not null references public.users(id) on delete cascade,
 course_id uuid not null,
 status text not null default 'ativa' check(status in ('ativa','concluida','cancelada')),
 progresso numeric(5,2) not null default 0 check(progresso between 0 and 100),
 matriculado_em timestamptz not null default now(),
 concluida_em timestamptz,
 updated_at timestamptz not null default now(),
 primary key(tenant_id,user_id,course_id),
 foreign key(tenant_id,course_id) references public.academy_courses(tenant_id,id) on delete cascade
);
create table public.academy_progress (
 tenant_id uuid not null,
 user_id uuid not null references public.users(id) on delete cascade,
 module_id uuid not null,
 course_id uuid not null,
 concluido boolean not null default false,
 tentativas integer not null default 0 check(tentativas>=0),
 nota numeric(5,2) check(nota is null or nota between 0 and 100),
 atualizado_em timestamptz not null default now(),
 primary key(tenant_id,user_id,module_id),
 foreign key(tenant_id,module_id) references public.academy_modules(tenant_id,id) on delete cascade,
 foreign key(tenant_id,course_id) references public.academy_courses(tenant_id,id) on delete cascade
);
create index academy_progress_course on public.academy_progress(tenant_id,course_id,user_id);
create table public.academy_events (
 id uuid primary key default gen_random_uuid(),
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 course_id uuid,
 actor_id uuid not null references public.users(id) on delete cascade,
 action text not null check(length(action) between 3 and 60),
 detail jsonb not null default '{}' check(jsonb_typeof(detail)='object'),
 created_at timestamptz not null default now(),
 foreign key(tenant_id,course_id) references public.academy_courses(tenant_id,id) on delete cascade
);
create index academy_events_actor on public.academy_events(tenant_id,actor_id,created_at desc);
-- Capacidade por tenant: default deny, excecoes allow/deny vencem a clausula contratual.
create or replace function erp_security.academy_capability(p_tenant uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_tenant is not null and
 (exists(select 1 from public.erp_tenant_capabilities e where e.tenant_id=p_tenant and e.capability_key='academy.courses'
  and e.status in ('trial','active') and (e.starts_at is null or e.starts_at<=now()) and (e.ends_at is null or e.ends_at>now()))
  or exists(select 1 from public.erp_tenant_capability_exceptions x where x.tenant_id=p_tenant and x.capability_key='academy.courses'
  and x.status='active' and x.effect='allow' and x.effective_from<=now() and x.expires_at>now()))
 and not exists(select 1 from public.erp_tenant_capability_exceptions x where x.tenant_id=p_tenant and x.capability_key='academy.courses'
  and x.status='active' and x.effect='deny' and x.effective_from<=now() and x.expires_at>now());
$$;
create or replace function erp_security.academy_access(p_tenant uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select p_tenant is not null and erp_security.is_tenant_member(p_tenant) and erp_security.academy_capability(p_tenant);
$$;
create or replace function erp_security.academy_manage(p_tenant uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select erp_security.academy_access(p_tenant) and erp_security.has_permission_at_aal(p_tenant,'academy.manage','aal1');
$$;
create or replace function public.academy_context(p_tenant uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('access',erp_security.academy_access(p_tenant),'manage',erp_security.academy_manage(p_tenant),'capability',erp_security.academy_capability(p_tenant));
$$;
-- Sem DML para clientes: toda transicao de estado passa pelo comando travado abaixo.
do $$ declare t text; begin
 foreach t in array array['academy_courses','academy_modules','academy_enrollments','academy_progress','academy_events'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;
create policy academy_course_read on public.academy_courses for select to authenticated
 using (erp_security.academy_access(tenant_id) or public.is_platform_staff());
create policy academy_module_read on public.academy_modules for select to authenticated
 using (erp_security.academy_access(tenant_id) or public.is_platform_staff());
create policy academy_enrollment_read on public.academy_enrollments for select to authenticated
 using ((user_id=(select auth.uid()) and erp_security.academy_access(tenant_id)) or erp_security.academy_manage(tenant_id) or public.is_platform_staff());
create policy academy_progress_read on public.academy_progress for select to authenticated
 using ((user_id=(select auth.uid()) and erp_security.academy_access(tenant_id)) or erp_security.academy_manage(tenant_id) or public.is_platform_staff());
create policy academy_event_read on public.academy_events for select to authenticated
 using ((actor_id=(select auth.uid()) or erp_security.academy_manage(tenant_id)) and erp_security.academy_access(tenant_id));
create or replace function public.academy_command(p_tenant uuid,p_action text,p_course uuid default null,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.academy_courses; m public.academy_modules; e public.academy_enrollments;
 uid uuid:=(select auth.uid()); manager boolean; total integer; done_n integer; prog numeric; v_order integer;
begin
 if p_tenant is null or uid is null then raise exception 'ACADEMY_CONTEXT_MISSING' using errcode='42501'; end if;
 if not coalesce(erp_security.academy_access(p_tenant),false) then raise exception 'ACADEMY_ACCESS_DENIED' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>50000 then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
 manager:=coalesce(erp_security.academy_manage(p_tenant),false);
 perform pg_advisory_xact_lock(hashtextextended('academy:'||p_tenant::text||':'||uid::text,0));
 if (select count(*) from public.academy_events where tenant_id=p_tenant and actor_id=uid and created_at>now()-interval '1 minute')>=120
  then raise exception 'ACADEMY_RATE_LIMIT' using errcode='54000'; end if;
 if p_action='create_course' then
  if not manager then raise exception 'ACADEMY_CURATOR_REQUIRED' using errcode='42501'; end if;
  if coalesce(length(btrim(coalesce(p_data->>'titulo',''))),0) not between 3 and 180 then raise exception 'ACADEMY_TITLE_REQUIRED' using errcode='22023'; end if;
  if length(coalesce(p_data->>'descricao',''))>5000 or coalesce(length(btrim(coalesce(p_data->>'categoria','Geral'))),0) not between 1 and 80
   or coalesce(p_data->>'idioma','pt-BR') not in ('pt-BR','es-419','en-US')
   or coalesce(p_data->>'nivel','iniciante') not in ('iniciante','intermediario','avancado')
   or (coalesce(p_data->>'capa_url','')<>'' and p_data->>'capa_url' !~ '^https://[^[:space:]]+$')
   then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
  insert into public.academy_courses(tenant_id,titulo,descricao,categoria,idioma,nivel,capa_url,created_by)
  values(p_tenant,btrim(p_data->>'titulo'),coalesce(p_data->>'descricao',''),coalesce(p_data->>'categoria','Geral'),
   coalesce(p_data->>'idioma','pt-BR'),coalesce(p_data->>'nivel','iniciante'),coalesce(p_data->>'capa_url',''),uid)
  returning * into c;
 elsif p_action='update_course' or p_action='publish_course' or p_action='add_module' then
  if not manager then raise exception 'ACADEMY_CURATOR_REQUIRED' using errcode='42501'; end if;
  select * into c from public.academy_courses where tenant_id=p_tenant and id=p_course for update;
  if c.id is null then raise exception 'ACADEMY_COURSE_NOT_FOUND' using errcode='42501'; end if;
  if p_action='update_course' then
   if p_data ? 'titulo' then
    if coalesce(length(btrim(p_data->>'titulo')),0) not between 3 and 180 then raise exception 'ACADEMY_TITLE_REQUIRED' using errcode='22023'; end if;
    c.titulo:=btrim(p_data->>'titulo');
   end if;
   if p_data ? 'descricao' then
    if length(coalesce(p_data->>'descricao',''))>5000 then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
    c.descricao:=p_data->>'descricao';
   end if;
   if p_data ? 'categoria' then
    if coalesce(length(btrim(p_data->>'categoria')),0) not between 1 and 80 then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
    c.categoria:=btrim(p_data->>'categoria');
   end if;
   if p_data ? 'idioma' and p_data->>'idioma' not in ('pt-BR','es-419','en-US') then raise exception 'ACADEMY_INVALID_LANGUAGE' using errcode='22023'; end if;
   if p_data ? 'nivel' and p_data->>'nivel' not in ('iniciante','intermediario','avancado') then raise exception 'ACADEMY_INVALID_LEVEL' using errcode='22023'; end if;
   if p_data ? 'capa_url' and p_data->>'capa_url'<>'' and p_data->>'capa_url' !~ '^https://[^[:space:]]+$' then raise exception 'ACADEMY_INVALID_URL' using errcode='22023'; end if;
   if p_data ? 'preco' and p_data->>'preco' !~ '^[0-9]{1,8}([.][0-9]{1,2})?$' then raise exception 'ACADEMY_INVALID_PRICE' using errcode='22023'; end if;
   if p_data ? 'duracao_min' and p_data->>'duracao_min' !~ '^[0-9]{1,6}$' then raise exception 'ACADEMY_INVALID_DURATION' using errcode='22023'; end if;
   if p_data ? 'ordem' and p_data->>'ordem' !~ '^[0-9]{1,6}$' then raise exception 'ACADEMY_INVALID_ORDER' using errcode='22023'; end if;
   c.idioma:=coalesce(p_data->>'idioma',c.idioma); c.nivel:=coalesce(p_data->>'nivel',c.nivel);
   c.capa_url:=coalesce(p_data->>'capa_url',c.capa_url);
   c.preco:=coalesce((p_data->>'preco')::numeric,c.preco);
   c.duracao_min:=coalesce((p_data->>'duracao_min')::integer,c.duracao_min);
   c.ordem:=coalesce((p_data->>'ordem')::integer,c.ordem);
   update public.academy_courses set titulo=c.titulo,descricao=c.descricao,categoria=c.categoria,idioma=c.idioma,
    nivel=c.nivel,capa_url=c.capa_url,preco=c.preco,duracao_min=c.duracao_min,ordem=c.ordem,updated_at=now()
    where tenant_id=p_tenant and id=c.id returning * into c;
  elsif p_action='publish_course' then
   if p_data->>'status' not in ('rascunho','publicado','arquivado') then raise exception 'ACADEMY_STATUS_INVALID' using errcode='22023'; end if;
   if p_data->>'status'='publicado' and not exists(select 1 from public.academy_modules mo where mo.tenant_id=p_tenant and mo.course_id=c.id)
    then raise exception 'ACADEMY_COURSE_EMPTY' using errcode='23514'; end if;
   update public.academy_courses set status=p_data->>'status',updated_at=now(),
    publicado_em=case when p_data->>'status'='publicado' and publicado_em is null then now() else publicado_em end
    where tenant_id=p_tenant and id=c.id returning * into c;
  else
   if coalesce(length(btrim(coalesce(p_data->>'titulo',''))),0) not between 3 and 180 then raise exception 'ACADEMY_MODULE_TITLE_REQUIRED' using errcode='22023'; end if;
   if coalesce(p_data->>'tipo','video') not in ('video','texto','pdf','quiz','prova') then raise exception 'ACADEMY_MODULE_KIND_INVALID' using errcode='22023'; end if;
   if p_data ? 'ordem' and p_data->>'ordem' !~ '^[0-9]{1,6}$' then raise exception 'ACADEMY_INVALID_ORDER' using errcode='22023'; end if;
   if p_data ? 'duracao_min' and p_data->>'duracao_min' !~ '^[0-9]{1,6}$' then raise exception 'ACADEMY_INVALID_DURATION' using errcode='22023'; end if;
   if coalesce(p_data->>'conteudo_ref','')<>'' and p_data->>'conteudo_ref' !~ '^(https://|academy:)' then raise exception 'ACADEMY_INVALID_CONTENT_REF' using errcode='22023'; end if;
   v_order:=case when p_data ? 'ordem' then (p_data->>'ordem')::integer
    else (select coalesce(max(mo2.ordem),-1)+1 from public.academy_modules mo2 where mo2.tenant_id=p_tenant and mo2.course_id=c.id) end;
   if exists(select 1 from public.academy_modules mo3 where mo3.tenant_id=p_tenant and mo3.course_id=c.id and mo3.ordem=v_order)
    then raise exception 'ACADEMY_MODULE_ORDER_CONFLICT' using errcode='23505'; end if;
   insert into public.academy_modules(tenant_id,course_id,titulo,tipo,conteudo_ref,duracao_min,ordem)
   values(p_tenant,c.id,btrim(p_data->>'titulo'),coalesce(p_data->>'tipo','video'),coalesce(p_data->>'conteudo_ref',''),
    coalesce((p_data->>'duracao_min')::integer,0),v_order) returning * into m;
   insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
    values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id,'module_id',m.id));
   return to_jsonb(m);
  end if;
 elsif p_action='enroll' then
  select * into c from public.academy_courses where tenant_id=p_tenant and id=p_course;
  if c.id is null or c.status<>'publicado' then raise exception 'ACADEMY_COURSE_NOT_AVAILABLE' using errcode='42501'; end if;
  insert into public.academy_enrollments(tenant_id,user_id,course_id) values(p_tenant,uid,c.id)
   on conflict(tenant_id,user_id,course_id) do update set status='ativa',concluida_em=null,updated_at=now() returning * into e;
  insert into public.academy_events(tenant_id,course_id,actor_id,action,detail) values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id));
  return jsonb_build_object('action','enroll','course_id',c.id,'status',e.status,'progresso',e.progresso);
 elsif p_action='unenroll' then
  update public.academy_enrollments set status='cancelada',updated_at=now()
   where tenant_id=p_tenant and user_id=uid and course_id=p_course and status<>'concluida' returning * into e;
  if e.course_id is null then raise exception 'ACADEMY_NOT_ENROLLED' using errcode='42501'; end if;
  insert into public.academy_events(tenant_id,course_id,actor_id,action,detail) values(p_tenant,p_course,uid,p_action,jsonb_build_object('course_id',p_course));
  return jsonb_build_object('action','unenroll','course_id',p_course,'status',e.status);
 elsif p_action='complete_module' then
  if coalesce(p_data->>'module_id','') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
   then raise exception 'ACADEMY_MODULE_REQUIRED' using errcode='22023'; end if;
  select * into m from public.academy_modules where tenant_id=p_tenant and id=(p_data->>'module_id')::uuid;
  if m.id is null then raise exception 'ACADEMY_MODULE_NOT_FOUND' using errcode='42501'; end if;
  select * into e from public.academy_enrollments where tenant_id=p_tenant and user_id=uid and course_id=m.course_id;
  if e.course_id is null or e.status<>'ativa' then raise exception 'ACADEMY_NOT_ENROLLED' using errcode='42501'; end if;
  insert into public.academy_progress(tenant_id,user_id,module_id,course_id,concluido,tentativas)
   values(p_tenant,uid,m.id,m.course_id,true,1)
   on conflict(tenant_id,user_id,module_id) do update set concluido=true,atualizado_em=now();
  select count(*),count(*) filter (where pr.concluido) into total,done_n
   from public.academy_modules mo4 left join public.academy_progress pr
    on pr.tenant_id=mo4.tenant_id and pr.module_id=mo4.id and pr.user_id=uid
   where mo4.tenant_id=p_tenant and mo4.course_id=m.course_id;
  prog:=case when coalesce(total,0)=0 then 0 else round(100.0::numeric*done_n/total,2) end;
  update public.academy_enrollments set progresso=prog,updated_at=now(),
   status=case when prog>=100 then 'concluida' else status end,
   concluida_em=case when prog>=100 and concluida_em is null then now() else concluida_em end
   where tenant_id=p_tenant and user_id=uid and course_id=m.course_id;
  insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
   values(p_tenant,m.course_id,uid,p_action,jsonb_build_object('module_id',m.id,'progresso',prog));
  return jsonb_build_object('action','complete_module','course_id',m.course_id,'progresso',prog,
   'concluido',(prog>=100));
 else
  raise exception 'ACADEMY_UNKNOWN_COMMAND' using errcode='22023';
 end if;
 insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
  values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id));
 return to_jsonb(c);
end $$;
-- Grants explicitos, incluindo helpers privados usados por RLS. Sem execucao anonima.
revoke all on function erp_security.academy_capability(uuid),erp_security.academy_access(uuid),erp_security.academy_manage(uuid),
 public.academy_context(uuid),public.academy_command(uuid,text,uuid,jsonb) from public,anon;
grant execute on function erp_security.academy_capability(uuid),erp_security.academy_access(uuid),erp_security.academy_manage(uuid),
 public.academy_context(uuid),public.academy_command(uuid,text,uuid,jsonb) to authenticated,service_role;
-- Corrige o 42501 verificado no catalogo publico (R-016): as policies da 0019 existem,
-- mas nenhum grant de SELECT acompanhou o hardening. Sem policy, grant nao vaza dado.
grant select on public.courses,public.products,public.cms_content to anon,authenticated;
grant select,insert on public.analytics_events to authenticated;
grant select on public.media_files to authenticated;
commit;
