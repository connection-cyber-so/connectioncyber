-- M23-G3: ativacao automatica condicionada a capacidade + gatilhos de capacidade.
-- Additivo sobre a 0048: a sincronia passa a exigir erp_security.academy_capability na
-- empresa (aceite: curso publico so liga nas empresas com a chave academy.courses ligada;
-- alvo de sistema/vertical idem) e toda transicao de capacidade/exception da chave
-- academy.courses recalcula os vinculos sozinho. Apply only after preflight and local/static validation.
begin;
-- 1) Regra de alvo ganha o corte de capacidade: toda empresa desejada precisa da chave
--    academy.courses ativa (trial/active na janela, allow vigente, sem deny) — inclusive o
--    dono do curso de escopo tenant (fail closed; a policy ja bloqueava a leitura sem a chave).
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
   where erp_security.academy_capability(t.id)
    and case
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
   where erp_security.academy_capability(t.id)
    and case
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
-- 2) Capacidade e contrato: ligar/desligar a chave academy.courses (ou uma exception
--    allow/deny) em erp_tenant_capabilities/erp_tenant_capability_exceptions ressincroniza
--    o catalogo inteiro (poucas empresas, barato). A funcao filtra por tg_op porque OLD nao
--    existe em INSERT e NEW nao existe em DELETE (evita erro de registro nao atribuido).
create or replace function public.academy_sync_capability_trg()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_key text;
begin
 v_key := case tg_op when 'DELETE' then old.capability_key else new.capability_key end;
 if v_key='academy.courses' then
  perform public.academy_sync_links();
 end if;
 return null;
end $$;
revoke all on function public.academy_sync_capability_trg() from public,anon;
grant execute on function public.academy_sync_capability_trg() to authenticated,service_role;
create trigger trg_academy_capabilities_sync
 after insert or update or delete on public.erp_tenant_capabilities
 for each row execute function public.academy_sync_capability_trg();
create trigger trg_academy_capability_exceptions_sync
 after insert or update or delete on public.erp_tenant_capability_exceptions
 for each row execute function public.academy_sync_capability_trg();
commit;
