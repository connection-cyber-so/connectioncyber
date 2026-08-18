-- Rate limiting transacional para APIs públicas serverless.

create table if not exists public.api_rate_limits (
  key            text primary key,
  window_started timestamptz not null default now(),
  request_count  integer not null default 1 check (request_count > 0)
);

alter table public.api_rate_limits enable row level security;
revoke all on public.api_rate_limits from public, anon, authenticated;

create or replace function public.consume_api_rate_limit(
  p_key text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count integer;
begin
  if p_limit < 1 or p_window_seconds < 1 then
    raise exception 'Parâmetros de rate limit inválidos';
  end if;

  insert into public.api_rate_limits as limits (key, window_started, request_count)
  values (p_key, now(), 1)
  on conflict (key) do update
    set window_started = case
          when limits.window_started <= now() - make_interval(secs => p_window_seconds) then now()
          else limits.window_started
        end,
        request_count = case
          when limits.window_started <= now() - make_interval(secs => p_window_seconds) then 1
          else limits.request_count + 1
        end
  returning request_count into current_count;

  return current_count <= p_limit;
end;
$$;

revoke all on function public.consume_api_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_api_rate_limit(text, integer, integer) to service_role;
