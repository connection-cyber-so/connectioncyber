-- Read-only; 0048 prerequisites and orphan checks before the FK rewrite. 0048 must be absent.
do $$
begin
  if to_regclass('public.academy_courses') is null
     or to_regprocedure('public.academy_command(uuid,text,uuid,jsonb)') is null then
    raise exception 'M23_G2_PREFLIGHT: fundacao da academia (migration 0044) ausente.';
  end if;
  if to_regclass('public.academy_tenant_courses') is not null then
    raise exception 'M23_G2_PREFLIGHT: academy_tenant_courses ja existe; migration 0048 ja aplicada.';
  end if;
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='academy_courses' and column_name='escopo') then
    raise exception 'M23_G2_PREFLIGHT: colunas de escopo ja existem; migration 0048 ja aplicada.';
  end if;
  if exists (select 1 from supabase_migrations.schema_migrations where version = '0048') then
    raise exception 'M23_G2_PREFLIGHT: migration 0048 ja aplicada.';
  end if;
  -- A FK nova (course_id/module_id simples) exige zero orfas: a composta antiga ja garantia,
  -- mas qualquer drift de dados precisaria de reparo antes do push.
  if exists (select 1 from public.academy_enrollments e
             left join public.academy_courses c on c.id=e.course_id where c.id is null) then
    raise exception 'M23_G2_PREFLIGHT: matriculas orfas de curso.';
  end if;
  if exists (select 1 from public.academy_progress p
             left join public.academy_courses c on c.id=p.course_id where c.id is null) then
    raise exception 'M23_G2_PREFLIGHT: progressos orfos de curso.';
  end if;
  if exists (select 1 from public.academy_progress p
             left join public.academy_modules m on m.id=p.module_id where m.id is null) then
    raise exception 'M23_G2_PREFLIGHT: progressos orfos de modulo.';
  end if;
  if exists (select 1 from public.academy_events e
             left join public.academy_courses c on c.id=e.course_id
             where e.course_id is not null and c.id is null) then
    raise exception 'M23_G2_PREFLIGHT: eventos orfos de curso.';
  end if;
end $$;
select 'M23_G2_PREFLIGHT_OK' as result, now() as checked_at;
select count(*) as cursos, count(*) filter (where status='publicado') as publicados,
       (select count(*) from public.academy_enrollments) as matriculas,
       (select count(*) from public.academy_events) as eventos from public.academy_courses;
-- Heranca do hardening 0044: anon le o catalogo legado e nao a academia.
select has_table_privilege('anon','public.courses','select') as anon_courses_select,
       has_table_privilege('anon','public.academy_courses','select') as anon_academy_select;
