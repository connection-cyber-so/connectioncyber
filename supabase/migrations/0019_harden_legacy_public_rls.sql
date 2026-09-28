-- ConnectionCyber — hardening das tabelas legadas expostas pelo PostgREST.
-- Política: deny-by-default; somente catálogos publicados são públicos.

begin;

alter table public.system_settings enable row level security;
alter table public.courses enable row level security;
alter table public.trails enable row level security;
alter table public.trail_steps enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_answers enable row level security;
alter table public.exams enable row level security;
alter table public.exam_questions enable row level security;
alter table public.products enable row level security;
alter table public.analytics_events enable row level security;
alter table public.media_files enable row level security;
alter table public.cms_content enable row level security;
alter table public.client_services enable row level security;
alter table public.remote_configs enable row level security;
alter table public.remote_automations enable row level security;

create policy courses_public_read_published
on public.courses for select
to anon, authenticated
using (status = 'publicado');

create policy products_public_read_active
on public.products for select
to anon, authenticated
using (status = 'ativo');

create policy cms_public_read_published
on public.cms_content for select
to anon, authenticated
using (publicado = true);

-- Analytics aceita somente eventos vinculados à própria identidade.
-- O backend administrativo continua usando service_role e ignora RLS.
create policy analytics_insert_own_event
on public.analytics_events for insert
to authenticated
with check (user_id = (select auth.uid()));

create policy analytics_read_own_events
on public.analytics_events for select
to authenticated
using (user_id = (select auth.uid()));

-- Arquivos privados permanecem visíveis apenas ao proprietário autenticado.
create policy media_read_own_files
on public.media_files for select
to authenticated
using (owner_id = (select auth.uid()));

commit;
