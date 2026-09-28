-- Rollback emergencial. Exige confirmação explícita na sessão.
do $$
begin
  if current_setting('app.rollback_confirmation', true) <> 'ROLLBACK_0019' then
    raise exception 'Defina app.rollback_confirmation=ROLLBACK_0019 para continuar.';
  end if;
end
$$;

begin;
drop policy if exists media_read_own_files on public.media_files;
drop policy if exists analytics_read_own_events on public.analytics_events;
drop policy if exists analytics_insert_own_event on public.analytics_events;
drop policy if exists cms_public_read_published on public.cms_content;
drop policy if exists products_public_read_active on public.products;
drop policy if exists courses_public_read_published on public.courses;

alter table public.system_settings disable row level security;
alter table public.courses disable row level security;
alter table public.trails disable row level security;
alter table public.trail_steps disable row level security;
alter table public.quizzes disable row level security;
alter table public.quiz_questions disable row level security;
alter table public.quiz_answers disable row level security;
alter table public.exams disable row level security;
alter table public.exam_questions disable row level security;
alter table public.products disable row level security;
alter table public.analytics_events disable row level security;
alter table public.media_files disable row level security;
alter table public.cms_content disable row level security;
alter table public.client_services disable row level security;
alter table public.remote_configs disable row level security;
alter table public.remote_automations disable row level security;
commit;
