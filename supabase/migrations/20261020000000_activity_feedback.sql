-- DriveTalk — who stopped using the app, and feedback from testers (D-079).
--
--   * Opening the app marks me "seen" (at most every 10 minutes).
--   * Friends see only whole days since I was last seen (no exact time),
--     so the app can say "hasn't opened DriveTalk for a week — remove?".
--   * "Send feedback": a short text to the owner (read in Supabase).

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 20 $$;
grant execute on function public.schema_version() to anon, authenticated;

create or replace function public.touch_seen()
returns void language sql security definer set search_path = public as $$
  update profiles set last_seen_at = now()
  where id = auth.uid() and last_seen_at < now() - interval '10 minutes';
$$;
revoke all on function public.touch_seen() from public, anon;
grant execute on function public.touch_seen() to authenticated;

-- My friends: whole days since each was last seen (0 = today).
create or replace function public.friends_activity()
returns table (user_id uuid, days integer)
language sql stable security definer set search_path = public as $$
  select p.id, floor(extract(epoch from now() - p.last_seen_at) / 86400)::integer
  from profiles p
  where p.id <> auth.uid()
    and are_connected(auth.uid(), p.id)
    and not is_blocked_between(auth.uid(), p.id);
$$;
revoke all on function public.friends_activity() from public, anon;
grant execute on function public.friends_activity() to authenticated;

create table if not exists public.feedback_notes (
  id bigserial primary key,
  user_id uuid references public.profiles (id) on delete set null default auth.uid(),
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  app_build integer,
  created_at timestamptz not null default now()
);
alter table public.feedback_notes enable row level security;
revoke all on public.feedback_notes from anon, authenticated;

create or replace function public.send_feedback(p_body text, p_build integer default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from feedback_notes
      where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'rate_limited';
  end if;
  insert into feedback_notes (user_id, body, app_build) values (auth.uid(), btrim(p_body), p_build);
end;
$$;
revoke all on function public.send_feedback(text, integer) from public, anon;
grant execute on function public.send_feedback(text, integer) to authenticated;

create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'users', (select count(*) from profiles),
    'new_users', (select count(*) from profiles where created_at >= since),
    'active_users', (select count(*) from profiles where last_seen_at >= since),
    'friendships', (select count(*) from connections),
    'free_times', (select count(*) from app_events where name = 'availability_started' and created_at >= since),
    'offers', (select count(*) from match_offers where created_at >= since and not quick),
    'quick', (select count(*) from match_offers where created_at >= since and quick),
    'both_yes', (select count(*) from match_offers where created_at >= since and status = 'accepted'),
    'talked', (select count(*) from match_offers where created_at >= since and talked),
    'declined', (select count(*) from match_offers where created_at >= since and status = 'declined'),
    'later', (select count(*) from match_offers where created_at >= since and later_from is not null),
    'no_answer', (select count(*) from match_offers where created_at >= since and status = 'expired'),
    'reports', (select count(*) from reports where created_at >= since),
    'feedback', (select count(*) from feedback_notes where created_at >= since),
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  );
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261020000000_activity_feedback') on conflict do nothing;
