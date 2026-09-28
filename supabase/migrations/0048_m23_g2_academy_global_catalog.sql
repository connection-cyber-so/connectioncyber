-- M23-G2: catalogo global de cursos + vinculo por tenant (modelo C+ aprovado 28/09/2026).
-- Additivo sobre a 0044: colunas de escopo/alvo, tabela de vinculo, sincronia automatica,
-- policies de leitura por vinculo, FKs simples (curso pode pertencer a outra empresa) e
-- acoes novas em academy_command. Apply only after preflight and local/static validation.
begin;
-- 1) Escopo e alvo do curso: tenant (isolado) ou global (ativo por regra para varias empresas).
alter table public.academy_courses
 add column escopo text not null default 'tenant',
 add column alvo_sistema text,
 add column alvo_vertical text,
 add column publico boolean not null default false;
alter table public.academy_courses
 add constraint academy_courses_escopo_chk check (escopo in ('tenant','global')),
 add constraint academy_courses_scope_target_chk check (
  (escopo='tenant' and not publico and alvo_sistema is null and alvo_vertical is null)
  or (escopo='global' and (publico or alvo_sistema is not null or alvo_vertical is not null))),
 add constraint academy_courses_alvo_sistema_chk check (alvo_sistema is null or alvo_sistema ~ '^[a-z0-9][a-z0-9_-]{0,59}$'),
 add constraint academy_courses_alvo_vertical_chk check (alvo_vertical is null or alvo_vertical ~ '^[a-z0-9][a-z0-9_-]{0,59}$');
-- 2) Fonte unica de "esta empresa oferece este curso". origem=auto vem da regra de alvo
-- (C+); origem=manual e vinculacao explicita do curador da empresa. Sincronia preserva manual.
create table public.academy_tenant_courses (
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 course_id uuid not null references public.academy_courses(id) on delete cascade,
 origem text not null default 'auto' check (origem in ('auto','manual')),
 ativo boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 primary key (tenant_id, course_id)
);
create index academy_tenant_courses_course on public.academy_tenant_courses(course_id,ativo);
create trigger trg_academy_tenant_courses_updated_at
 before update on public.academy_tenant_courses
 for each row execute function public.set_updated_at();
alter table public.academy_tenant_courses enable row level security;
revoke all on public.academy_tenant_courses from public,anon,authenticated;
grant select on public.academy_tenant_courses to authenticated;
grant all on public.academy_tenant_courses to service_role;
create policy academy_tenant_course_read on public.academy_tenant_courses for select to authenticated
 using (erp_security.academy_access(tenant_id) or public.is_platform_staff());
-- 3) Sincronia C+: recalcula apenas vinculos auto para o curso alterado (p_course) ou todos.
-- Regras: curso do proprio tenant => vinculo dele; global publico => todas as empresas;
-- global com alvo => empresas com tenant_modules ativo (alvo_sistema) ou da vertical (alvo_vertical).
create or replace function public.academy_sync_links(p_course uuid default null)
returns integer language plpgsql security definer set search_path='' as $$
declare r record; v_del integer; v_ins integer; v_total integer:=0;
begin
 for r in
  select id,tenant_id,escopo,publico,alvo_sistema,alvo_vertical
  from public.academy_courses where (p_course is null or id=p_course)
 loop
  with desired as (
   select t.id as tenant_id from public.tenants t
   where case
    when r.escopo='tenant' then t.id=r.tenant_id
    when r.publico then true
    else (r.alvo_sistema is not null
          and exists(select 1 from public.tenant_modules tm
                     where tm.tenant_id=t.id and tm.module_key=r.alvo_sistema and tm.status='ativo'))
      or (r.alvo_vertical is not null and t.vertical=r.alvo_vertical)
   end
  )
  delete from public.academy_tenant_courses tc
  where tc.course_id=r.id and tc.origem='auto'
    and not exists(select 1 from desired d where d.tenant_id=tc.tenant_id);
  get diagnostics v_del=row_count;
  with desired as (
   select t.id as tenant_id from public.tenants t
   where case
    when r.escopo='tenant' then t.id=r.tenant_id
    when r.publico then true
    else (r.alvo_sistema is not null
          and exists(select 1 from public.tenant_modules tm
                     where tm.tenant_id=t.id and tm.module_key=r.alvo_sistema and tm.status='ativo'))
      or (r.alvo_vertical is not null and t.vertical=r.alvo_vertical)
   end
  )
  insert into public.academy_tenant_courses(tenant_id,course_id,origem,ativo)
  select d.tenant_id,r.id,'auto',true from desired d
  where not exists(select 1 from public.academy_tenant_courses tc
                   where tc.tenant_id=d.tenant_id and tc.course_id=r.id)
  on conflict (tenant_id,course_id) do nothing;
  get diagnostics v_ins=row_count;
  v_total:=v_total+v_del+v_ins;
 end loop;
 return v_total;
end $$;
revoke all on function public.academy_sync_links(uuid) from public,anon;
grant execute on function public.academy_sync_links(uuid) to authenticated,service_role;
-- 4) Gatilhos: curso novo/editado ressincroniza sozinho; mudanca de capacidade de modulo
-- (tenant_modules) ou de vertical da empresa ressincroniza tudo (catalogo pequeno, barato).
create or replace function public.academy_sync_links_trg()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform public.academy_sync_links(case when tg_op='DELETE' then old.id else new.id end);
 return case when tg_op='DELETE' then old else new end;
end $$;
create trigger trg_academy_courses_sync
 after insert or update or delete on public.academy_courses
 for each row execute function public.academy_sync_links_trg();
create or replace function public.academy_sync_all_trg()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform public.academy_sync_links();
 return null;
end $$;
create trigger trg_tenant_modules_academy_sync
 after insert or update or delete on public.tenant_modules
 for each row execute function public.academy_sync_all_trg();
create trigger trg_tenants_academy_sync_insert
 after insert on public.tenants
 for each row execute function public.academy_sync_all_trg();
create trigger trg_tenants_academy_sync_vertical
 after update of vertical on public.tenants
 for each row execute function public.academy_sync_all_trg();
-- 5) FKs compostas (tenant_id,curso/modulo) viram simples: matricula e progresso pertencem
-- a empresa do aluno, nao a empresa dona do curso. academy_modules mantem a composta (dono).
do $$
declare r record;
begin
 for r in
  select con.conname, con.conrelid::regclass as tbl
  from pg_constraint con
  where con.contype='f'
    and con.confrelid='public.academy_courses'::regclass
    and con.conrelid<>'public.academy_modules'::regclass
    and con.conkey=(select array_agg(attnum order by attnum) from pg_attribute
                    where attrelid=con.conrelid and attname in ('tenant_id','course_id'))
 loop
  execute format('alter table %s drop constraint %I',r.tbl,r.conname);
 end loop;
 for r in
  select con.conname, con.conrelid::regclass as tbl
  from pg_constraint con
  where con.contype='f'
    and con.confrelid='public.academy_modules'::regclass
    and con.conkey=(select array_agg(attnum order by attnum) from pg_attribute
                    where attrelid=con.conrelid and attname in ('tenant_id','module_id'))
 loop
  execute format('alter table %s drop constraint %I',r.tbl,r.conname);
 end loop;
end $$;
alter table public.academy_enrollments
 add constraint academy_enrollments_course_fkey foreign key(course_id) references public.academy_courses(id) on delete cascade;
alter table public.academy_progress
 add constraint academy_progress_course_fkey foreign key(course_id) references public.academy_courses(id) on delete cascade;
alter table public.academy_progress
 add constraint academy_progress_module_fkey foreign key(module_id) references public.academy_modules(id) on delete cascade;
alter table public.academy_events
 add constraint academy_events_course_fkey foreign key(course_id) references public.academy_courses(id) on delete cascade;
-- 6) Leitura por vinculo: curso do proprio tenant (escopo tenant) ou curso global com
-- vinculo ativo em empresa onde o usuario tem acesso (membro + capacidade academy.courses).
-- Excecao de descoberta: gestor (academy.manage) enxerga o catalogo global inteiro para
-- poder vincular/desvincular; aluno comum continua gated pelo vinculo.
drop policy academy_course_read on public.academy_courses;
create policy academy_course_read on public.academy_courses for select to authenticated
 using (public.is_platform_staff()
  or (erp_security.academy_access(tenant_id) and escopo='tenant')
  or exists(select 1 from public.academy_tenant_courses tc
            where tc.course_id=academy_courses.id and tc.ativo and erp_security.academy_access(tc.tenant_id))
  or (escopo='global' and exists(select 1 from public.erp_tenant_memberships m
        where m.user_id=(select auth.uid()) and m.status='active'
          and erp_security.academy_manage(m.tenant_id))));
drop policy academy_module_read on public.academy_modules;
create policy academy_module_read on public.academy_modules for select to authenticated
 using (public.is_platform_staff()
  or (erp_security.academy_access(tenant_id)
      and exists(select 1 from public.academy_courses c
                 where c.id=academy_modules.course_id and c.escopo='tenant'))
  or exists(select 1 from public.academy_tenant_courses tc
            where tc.course_id=academy_modules.course_id and tc.ativo and erp_security.academy_access(tc.tenant_id)));
-- 7) Contexto passa a expor 'staff' (só a plataforma cria/edita alvo de curso global).
create or replace function public.academy_context(p_tenant uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('access',erp_security.academy_access(p_tenant),'manage',erp_security.academy_manage(p_tenant),
  'capability',erp_security.academy_capability(p_tenant),'staff',public.is_platform_staff());
$$;
-- 8) Validacao unica de alvo: publico=true nao tem alvo; sem publico exige sistema e/ou vertical.
create or replace function public.academy_validate_targets(p_publico boolean,p_sistema text,p_vertical text)
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if coalesce(p_publico,false) then return; end if;
 if p_sistema is null and p_vertical is null
  then raise exception 'ACADEMY_GLOBAL_TARGET_REQUIRED' using errcode='22023'; end if;
 if p_sistema is not null and (p_sistema !~ '^[a-z0-9][a-z0-9_-]{0,59}$'
    or not exists(select 1 from public.module_catalog mc where mc.key=p_sistema))
  then raise exception 'ACADEMY_INVALID_TARGET' using errcode='22023'; end if;
 if p_vertical is not null and p_vertical !~ '^[a-z0-9][a-z0-9_-]{0,59}$'
  then raise exception 'ACADEMY_INVALID_TARGET' using errcode='22023'; end if;
end $$;
revoke all on function public.academy_validate_targets(boolean,text,text) from public,anon;
grant execute on function public.academy_validate_targets(boolean,text,text) to authenticated,service_role;
-- 9) Comando reescrito: resolve curso por id (aceita global), módulos nascem no dono,
-- matricula/progresso exigem vinculo ativo, e entram link_course/unlink_course/set_course_targets.
create or replace function public.academy_command(p_tenant uuid,p_action text,p_course uuid default null,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.academy_courses; m public.academy_modules; e public.academy_enrollments;
 uid uuid:=(select auth.uid()); manager boolean; staff boolean; total integer; done_n integer; prog numeric;
 v_order integer; v_escopo text; v_publico boolean; v_sistema text; v_vertical text; v_origem text;
begin
 if p_tenant is null or uid is null then raise exception 'ACADEMY_CONTEXT_MISSING' using errcode='42501'; end if;
 if not coalesce(erp_security.academy_access(p_tenant),false) then raise exception 'ACADEMY_ACCESS_DENIED' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>50000 then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
 manager:=coalesce(erp_security.academy_manage(p_tenant),false);
 staff:=coalesce(public.is_platform_staff(),false);
 perform pg_advisory_xact_lock(hashtextextended('academy:'||p_tenant::text||':'||uid::text,0));
 if (select count(*) from public.academy_events where tenant_id=p_tenant and actor_id=uid and created_at>now()-interval '1 minute')>=120
  then raise exception 'ACADEMY_RATE_LIMIT' using errcode='54000'; end if;
 if p_action='create_course' then
  if not (manager or staff) then raise exception 'ACADEMY_CURATOR_REQUIRED' using errcode='42501'; end if;
  if coalesce(length(btrim(coalesce(p_data->>'titulo',''))),0) not between 3 and 180 then raise exception 'ACADEMY_TITLE_REQUIRED' using errcode='22023'; end if;
  if length(coalesce(p_data->>'descricao',''))>5000 or coalesce(length(btrim(coalesce(p_data->>'categoria','Geral'))),0) not between 1 and 80
   or coalesce(p_data->>'idioma','pt-BR') not in ('pt-BR','es-419','en-US')
   or coalesce(p_data->>'nivel','iniciante') not in ('iniciante','intermediario','avancado')
   or (coalesce(p_data->>'capa_url','')<>'' and p_data->>'capa_url' !~ '^https://[^[:space:]]+$')
   then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
  v_escopo:=coalesce(p_data->>'escopo','tenant');
  if v_escopo='tenant' then
   v_publico:=false; v_sistema:=null; v_vertical:=null;
  elsif v_escopo='global' then
   if not staff then raise exception 'ACADEMY_PLATFORM_REQUIRED' using errcode='42501'; end if;
   if p_data ? 'publico' and p_data->>'publico' not in ('true','false')
    then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
   v_publico:=coalesce((p_data->>'publico')::boolean,true);
   if v_publico then v_sistema:=null; v_vertical:=null;
   else
    v_sistema:=nullif(btrim(coalesce(p_data->>'alvo_sistema','')),'');
    v_vertical:=nullif(btrim(coalesce(p_data->>'alvo_vertical','')),'');
   end if;
   perform public.academy_validate_targets(v_publico,v_sistema,v_vertical);
  else
   raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023';
  end if;
  insert into public.academy_courses(tenant_id,titulo,descricao,categoria,idioma,nivel,capa_url,created_by,escopo,publico,alvo_sistema,alvo_vertical)
  values(p_tenant,btrim(p_data->>'titulo'),coalesce(p_data->>'descricao',''),coalesce(p_data->>'categoria','Geral'),
   coalesce(p_data->>'idioma','pt-BR'),coalesce(p_data->>'nivel','iniciante'),coalesce(p_data->>'capa_url',''),uid,
   v_escopo,v_publico,v_sistema,v_vertical)
  returning * into c;
 elsif p_action='link_course' or p_action='unlink_course' then
  if not (manager or staff) then raise exception 'ACADEMY_CURATOR_REQUIRED' using errcode='42501'; end if;
  select * into c from public.academy_courses where id=p_course for update;
  if c.id is null or c.escopo<>'global' then raise exception 'ACADEMY_LINK_ONLY_GLOBAL' using errcode='42501'; end if;
  if p_action='link_course' then
   insert into public.academy_tenant_courses(tenant_id,course_id,origem,ativo) values(p_tenant,c.id,'manual',true)
    on conflict (tenant_id,course_id) do update set ativo=true;
   insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
    values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id));
   return jsonb_build_object('action','link_course','course_id',c.id,'tenant_id',p_tenant);
  end if;
  select origem into v_origem from public.academy_tenant_courses where tenant_id=p_tenant and course_id=c.id;
  if v_origem is null then raise exception 'ACADEMY_COURSE_NOT_LINKED' using errcode='42501'; end if;
  if v_origem<>'manual' then raise exception 'ACADEMY_LINK_AUTO' using errcode='42501'; end if;
  delete from public.academy_tenant_courses where tenant_id=p_tenant and course_id=c.id;
  insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
   values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id));
  return jsonb_build_object('action','unlink_course','course_id',c.id,'tenant_id',p_tenant);
 elsif p_action='set_course_targets' then
  if not staff then raise exception 'ACADEMY_PLATFORM_REQUIRED' using errcode='42501'; end if;
  select * into c from public.academy_courses where id=p_course for update;
  if c.id is null or c.escopo<>'global' then raise exception 'ACADEMY_TARGET_ONLY_GLOBAL' using errcode='42501'; end if;
  if p_data ? 'publico' and p_data->>'publico' not in ('true','false')
   then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
  v_publico:=case when p_data ? 'publico' then (p_data->>'publico')::boolean else c.publico end;
  if v_publico then v_sistema:=null; v_vertical:=null;
  else
   v_sistema:=case when p_data ? 'alvo_sistema' then nullif(btrim(coalesce(p_data->>'alvo_sistema','')),'') else c.alvo_sistema end;
   v_vertical:=case when p_data ? 'alvo_vertical' then nullif(btrim(coalesce(p_data->>'alvo_vertical','')),'') else c.alvo_vertical end;
  end if;
  perform public.academy_validate_targets(v_publico,v_sistema,v_vertical);
  update public.academy_courses set publico=v_publico,alvo_sistema=v_sistema,alvo_vertical=v_vertical,updated_at=now()
   where id=c.id returning * into c;
  insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
   values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id,'publico',c.publico,
    'alvo_sistema',c.alvo_sistema,'alvo_vertical',c.alvo_vertical));
  return jsonb_build_object('action','set_course_targets','course_id',c.id,'publico',c.publico,
   'alvo_sistema',c.alvo_sistema,'alvo_vertical',c.alvo_vertical);
 elsif p_action='update_course' or p_action='publish_course' or p_action='add_module' then
  if not (manager or staff) then raise exception 'ACADEMY_CURATOR_REQUIRED' using errcode='42501'; end if;
  select * into c from public.academy_courses where id=p_course and (tenant_id=p_tenant or escopo='global') for update;
  if c.id is null then raise exception 'ACADEMY_COURSE_NOT_FOUND' using errcode='42501'; end if;
  if c.escopo='global' and c.tenant_id<>p_tenant and not staff
   then raise exception 'ACADEMY_CURATOR_REQUIRED' using errcode='42501'; end if;
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
    if coalesce(length(btrim(coalesce(p_data->>'categoria','Geral'))),0) not between 1 and 80 then raise exception 'ACADEMY_INVALID_INPUT' using errcode='22023'; end if;
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
    where id=c.id returning * into c;
  elsif p_action='publish_course' then
   if p_data->>'status' not in ('rascunho','publicado','arquivado') then raise exception 'ACADEMY_STATUS_INVALID' using errcode='22023'; end if;
   if p_data->>'status'='publicado' and not exists(select 1 from public.academy_modules mo where mo.course_id=c.id)
    then raise exception 'ACADEMY_COURSE_EMPTY' using errcode='23514'; end if;
   update public.academy_courses set status=p_data->>'status',updated_at=now(),
    publicado_em=case when p_data->>'status'='publicado' and publicado_em is null then now() else publicado_em end
    where id=c.id returning * into c;
  else
   if coalesce(length(btrim(coalesce(p_data->>'titulo',''))),0) not between 3 and 180 then raise exception 'ACADEMY_MODULE_TITLE_REQUIRED' using errcode='22023'; end if;
   if coalesce(p_data->>'tipo','video') not in ('video','texto','pdf','quiz','prova') then raise exception 'ACADEMY_MODULE_KIND_INVALID' using errcode='22023'; end if;
   if p_data ? 'ordem' and p_data->>'ordem' !~ '^[0-9]{1,6}$' then raise exception 'ACADEMY_INVALID_ORDER' using errcode='22023'; end if;
   if p_data ? 'duracao_min' and p_data->>'duracao_min' !~ '^[0-9]{1,6}$' then raise exception 'ACADEMY_INVALID_DURATION' using errcode='22023'; end if;
   if coalesce(p_data->>'conteudo_ref','')<>'' and p_data->>'conteudo_ref' !~ '^(https://|academy:)' then raise exception 'ACADEMY_INVALID_CONTENT_REF' using errcode='22023'; end if;
   v_order:=case when p_data ? 'ordem' then (p_data->>'ordem')::integer
    else (select coalesce(max(mo2.ordem),-1)+1 from public.academy_modules mo2 where mo2.course_id=c.id) end;
   if exists(select 1 from public.academy_modules mo3 where mo3.course_id=c.id and mo3.ordem=v_order)
    then raise exception 'ACADEMY_MODULE_ORDER_CONFLICT' using errcode='23505'; end if;
   insert into public.academy_modules(tenant_id,course_id,titulo,tipo,conteudo_ref,duracao_min,ordem)
   values(c.tenant_id,c.id,btrim(p_data->>'titulo'),coalesce(p_data->>'tipo','video'),coalesce(p_data->>'conteudo_ref',''),
    coalesce((p_data->>'duracao_min')::integer,0),v_order) returning * into m;
   insert into public.academy_events(tenant_id,course_id,actor_id,action,detail)
    values(p_tenant,c.id,uid,p_action,jsonb_build_object('course_id',c.id,'module_id',m.id));
   return to_jsonb(m);
  end if;
 elsif p_action='enroll' then
  select * into c from public.academy_courses where id=p_course;
  if c.id is null or c.status<>'publicado' then raise exception 'ACADEMY_COURSE_NOT_AVAILABLE' using errcode='42501'; end if;
  if not exists(select 1 from public.academy_tenant_courses tc
                where tc.tenant_id=p_tenant and tc.course_id=c.id and tc.ativo)
   then raise exception 'ACADEMY_COURSE_NOT_AVAILABLE' using errcode='42501'; end if;
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
  select * into m from public.academy_modules where id=(p_data->>'module_id')::uuid;
  if m.id is null then raise exception 'ACADEMY_MODULE_NOT_FOUND' using errcode='42501'; end if;
  if not exists(select 1 from public.academy_tenant_courses tc
                where tc.tenant_id=p_tenant and tc.course_id=m.course_id and tc.ativo)
   then raise exception 'ACADEMY_COURSE_NOT_AVAILABLE' using errcode='42501'; end if;
  select * into e from public.academy_enrollments where tenant_id=p_tenant and user_id=uid and course_id=m.course_id;
  if e.course_id is null or e.status<>'ativa' then raise exception 'ACADEMY_NOT_ENROLLED' using errcode='42501'; end if;
  insert into public.academy_progress(tenant_id,user_id,module_id,course_id,concluido,tentativas)
   values(p_tenant,uid,m.id,m.course_id,true,1)
   on conflict(tenant_id,user_id,module_id) do update set concluido=true,atualizado_em=now();
  select count(*),count(*) filter (where pr.concluido) into total,done_n
   from public.academy_modules mo4 left join public.academy_progress pr
    on pr.module_id=mo4.id and pr.user_id=uid and pr.tenant_id=p_tenant
   where mo4.course_id=m.course_id;
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
-- 10) Semente dos vinculos para os cursos que ja existem (idempotente dentro da transacao).
select public.academy_sync_links();
comment on table public.academy_tenant_courses is
 'Vinculo empresa<->curso (C+): origem=auto vem da regra de alvo, origem>manual e vinculacao do curador. Leitura do catalogo e sempre por aqui.';
commit;
