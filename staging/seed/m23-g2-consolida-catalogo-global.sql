-- M23-G2.2 — consolidação de dados 3 → 1 (staging ozvylnaipubrmaadikvk, 28/09/2026)
-- Os 3 cursos réplica do G1 ("Atalhos de Teclado — Windows e Office" em Loja da Benção,
-- Casa de Bolos Aconchego e Mania de Modas) viram 1 curso global público ligado a toda
-- empresa. Executar DEPOIS do apply da 0048 (usa as tabelas/policies novas).
-- Idempotente: roda de novo e vira no-op (B/C já não existem; A já é global).
-- Uso: supabase db query --linked -f staging/seed/m23-g2-consolida-catalogo-global.sql

do $$
declare
  v_title text := 'Atalhos de Teclado — Windows e Office';
  v_tenant_a uuid := 'ef7d3cbc-f50c-4306-9b1b-3b5be75c3a5c'; -- Loja da Benção (base)
  v_tenant_b uuid := 'a673859e-18f9-4c01-84aa-4b6d92774874'; -- Casa de Bolos Aconchego
  v_tenant_c uuid := '7f2f05c7-94a0-42dc-bcfc-7b3105c391e3'; -- Mania de Modas
  v_course_a uuid;
  v_course_b uuid;
  v_course_c uuid;
  v_enroll integer;
  v_prog integer;
  v_links integer;
begin
  select id into v_course_a from public.academy_courses
   where tenant_id = v_tenant_a and titulo = v_title;
  if v_course_a is null then
    raise notice 'm23-g2: curso base nao encontrado — nada a fazer (ja consolidado?)';
    return;
  end if;

  -- 1) base vira global público: o gatilho da 0048 propaga vinculo 'auto' para as
  --    empresas com capacidade academy.courses e ressincroniza alvos (null aqui).
  update public.academy_courses
     set escopo = 'global', publico = true, alvo_sistema = null, alvo_vertical = null,
         updated_at = now()
   where id = v_course_a
     and (escopo <> 'global' or publico is distinct from true
          or alvo_sistema is not null or alvo_vertical is not null);

  select id into v_course_b from public.academy_courses
   where tenant_id = v_tenant_b and titulo = v_title;
  select id into v_course_c from public.academy_courses
   where tenant_id = v_tenant_c and titulo = v_title;

  -- 2) matrículas das réplicas migram para A (PK (tenant,user,course) — conflito pula;
  --    depois as réplicas são apagadas). FK de course_id já é simples (0048).
  insert into public.academy_enrollments
    (tenant_id, user_id, course_id, status, progresso, matriculado_em, concluida_em, updated_at)
  select e.tenant_id, e.user_id, v_course_a, e.status, e.progresso,
         e.matriculado_em, e.concluida_em, now()
    from public.academy_enrollments e
   where e.course_id in (v_course_b, v_course_c)
     and not exists (select 1 from public.academy_enrollments x
                      where x.tenant_id = e.tenant_id
                        and x.user_id = e.user_id
                        and x.course_id = v_course_a)
  on conflict do nothing;
  get diagnostics v_enroll = row_count;
  delete from public.academy_enrollments where course_id in (v_course_b, v_course_c);

  -- 3) progresso remapeado módulo a módulo (os 3 cursos têm os mesmos 8 ordem).
  --    Primeiro derruba colisões da PK (tenant,user,module): alvo já ocupado em A,
  --    ou duas réplicas apontando para o mesmo alvo (mantém a mais nova).
  delete from public.academy_progress p
   where p.course_id in (v_course_b, v_course_c)
     and (
       exists (select 1 from public.academy_modules bm
                 join public.academy_modules am
                   on am.course_id = v_course_a and am.ordem = bm.ordem
                where bm.id = p.module_id
                  and exists (select 1 from public.academy_progress x
                               where x.tenant_id = p.tenant_id
                                 and x.user_id = p.user_id
                                 and x.module_id = am.id))
       or exists (select 1 from public.academy_progress q
                    join public.academy_modules qm on qm.id = q.module_id
                    join public.academy_modules qam
                      on qam.course_id = v_course_a and qam.ordem = qm.ordem
                   where q.tenant_id = p.tenant_id
                     and q.user_id = p.user_id
                     and q.course_id in (v_course_b, v_course_c)
                     and q.ctid > p.ctid
                     and exists (select 1 from public.academy_modules pm
                                   join public.academy_modules pam
                                     on pam.course_id = v_course_a and pam.ordem = pm.ordem
                                  where pm.id = p.module_id and pam.id = qam.id))
     );
  get diagnostics v_prog = row_count;
  update public.academy_progress p
     set course_id = v_course_a, module_id = am.id, atualizado_em = now()
    from public.academy_modules bm, public.academy_modules am
   where p.course_id in (v_course_b, v_course_c)
     and bm.id = p.module_id
     and am.course_id = v_course_a
     and am.ordem = bm.ordem;

  -- 4) histórico de eventos passa a apontar para A (FK de course_id simples).
  update public.academy_events set course_id = v_course_a
   where course_id in (v_course_b, v_course_c);

  -- 5) réplicas somem: módulos restantes, links e resíduos caem em cascata.
  delete from public.academy_courses where id in (v_course_b, v_course_c);

  -- 6) "ligado para toda empresa": sync cobriu quem tem capacidade; o resto entra
  --    como vínculo manual (sem sobrepor nenhum vínculo já existente).
  insert into public.academy_tenant_courses (tenant_id, course_id, origem, ativo)
  select t.id, v_course_a, 'manual', true
    from public.tenants t
   where not exists (select 1 from public.academy_tenant_courses tc
                      where tc.tenant_id = t.id and tc.course_id = v_course_a)
  on conflict (tenant_id, course_id) do nothing;
  get diagnostics v_links = row_count;

  raise notice 'm23-g2: consolidado % (matriculas movidas=%, colisoes de progresso=%, links manuais novos=%)',
    v_course_a, v_enroll, v_prog, v_links;
end$$;

-- Conferência final: 1 curso global, réplicas fora, vínculos cobrindo todas as empresas.
select c.id, c.tenant_id, c.escopo, c.publico, c.status,
       (select count(*) from public.academy_modules m where m.course_id = c.id) as modulos,
       (select count(*) from public.academy_tenant_courses tc where tc.course_id = c.id) as vinculos,
       (select count(*) from public.tenants) as empresas
  from public.academy_courses c
 where c.titulo = 'Atalhos de Teclado — Windows e Office'
 order by c.escopo;
