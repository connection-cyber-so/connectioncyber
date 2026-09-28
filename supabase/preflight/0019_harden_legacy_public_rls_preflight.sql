-- Somente leitura: recusa se a migration 0019 já estiver aplicada ou incompleta.
do $$
declare
  target text;
begin
  foreach target in array array[
    'system_settings','courses','trails','trail_steps','quizzes','quiz_questions',
    'quiz_answers','exams','exam_questions','products','analytics_events','media_files',
    'cms_content','client_services','remote_configs','remote_automations'
  ] loop
    if to_regclass(format('public.%I', target)) is null then
      raise exception 'M0019_PREFLIGHT: tabela ausente: public.%', target;
    end if;
  end loop;

  if exists (
    select 1 from supabase_migrations.schema_migrations where version = '0019'
  ) then
    raise exception 'M0019_PREFLIGHT: migration 0019 já aplicada.';
  end if;
end
$$;

select 'M0019_PREFLIGHT_OK' as result, now() as checked_at;
