-- TapReply backend schema (Supabase / Postgres).
-- Every table has Row Level Security enabled AND forced, with no policy:
-- only the Edge Functions (service role) can read or write. The app never talks to the database directly.

create table if not exists public.tapreply_usage (      -- daily reply counter (fair use + stats)
  app_user_id text not null,
  day date not null,
  count integer not null default 0,
  primary key (app_user_id, day)
);

create table if not exists public.tapreply_grants (     -- welcome credits granted once per anonymous user
  app_user_id text primary key,
  granted_at timestamptz not null default now()
);

create table if not exists public.tapreply_rate (       -- atomic sliding-window rate limiting
  key text primary key,
  window_start timestamptz not null default now(),
  count integer not null default 0
);

create table if not exists public.tapreply_events (     -- anonymous product analytics (opt-out in Settings), 13-month retention
  id bigserial primary key,
  app_user_id text not null,
  name text not null,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.tapreply_admin (      -- token for the private stats dashboard
  id integer primary key default 1,
  stats_token text not null
);

do $$ declare t text; begin
  foreach t in array array['tapreply_usage','tapreply_grants','tapreply_rate','tapreply_events','tapreply_admin'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
  end loop;
end $$;

-- ------------------------------------------------------------------ RPCs used by the Edge Function
create or replace function public.tapreply_bump_usage(p_user text) returns integer
language sql set search_path to 'public', 'pg_temp' as $$
  insert into public.tapreply_usage as u (app_user_id, day, count)
  values (p_user, (now() at time zone 'utc')::date, 1)
  on conflict (app_user_id, day) do update set count = u.count + 1
  returning count;
$$;

create or replace function public.tapreply_unbump_usage(p_user text) returns void
language sql set search_path to 'public', 'pg_temp' as $$
  update public.tapreply_usage set count = greatest(count - 1, 0)
   where app_user_id = p_user and day = (now() at time zone 'utc')::date;
$$;

create or replace function public.tapreply_claim_welcome(p_user text) returns boolean
language plpgsql set search_path to 'public', 'pg_temp' as $$
begin
  insert into public.tapreply_grants (app_user_id) values (p_user) on conflict (app_user_id) do nothing;
  return found;
end $$;

create or replace function public.tapreply_release_welcome(p_user text) returns void
language sql set search_path to 'public', 'pg_temp' as $$
  delete from public.tapreply_grants where app_user_id = p_user;
$$;

create or replace function public.tapreply_rate_hit(p_key text, p_window_s integer, p_max integer) returns boolean
language plpgsql set search_path to 'public', 'pg_temp' as $$
declare v_count integer;
begin
  insert into public.tapreply_rate as r (key, window_start, count) values (p_key, now(), 1)
  on conflict (key) do update
    set count = case when r.window_start < now() - make_interval(secs => p_window_s) then 1 else r.count + 1 end,
        window_start = case when r.window_start < now() - make_interval(secs => p_window_s) then now() else r.window_start end
  returning count into v_count;
  if random() < 0.005 then delete from public.tapreply_rate where window_start < now() - interval '2 days'; end if;
  return v_count <= p_max;
end $$;

create or replace function public.tapreply_purge_events() returns void
language sql set search_path to 'public', 'pg_temp' as $$
  delete from public.tapreply_events where created_at < now() - interval '13 months';
  delete from public.tapreply_usage where day < (now() - interval '12 months')::date;
$$;

do $$ declare f text; begin
  foreach f in array array['tapreply_bump_usage(text)','tapreply_unbump_usage(text)','tapreply_claim_welcome(text)',
                           'tapreply_release_welcome(text)','tapreply_rate_hit(text,integer,integer)','tapreply_purge_events()'] loop
    execute format('revoke execute on function public.%s from public, anon, authenticated', f);
  end loop;
end $$;
