begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pgtap;

select plan(21);

select ok(c.relrowsecurity, format('RLS ativo em public.%s', c.relname))
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = any(array[
    'system_settings','courses','trails','trail_steps','quizzes','quiz_questions',
    'quiz_answers','exams','exam_questions','products','analytics_events','media_files',
    'cms_content','client_services','remote_configs','remote_automations'
  ])
order by c.relname;

select policies_are('public', 'courses', array['courses_public_read_published']);
select policies_are('public', 'products', array['products_public_read_active']);
select policies_are('public', 'cms_content', array['cms_public_read_published']);
select policies_are('public', 'analytics_events', array['analytics_insert_own_event','analytics_read_own_events']);
select policies_are('public', 'media_files', array['media_read_own_files']);

select * from finish();
rollback;
