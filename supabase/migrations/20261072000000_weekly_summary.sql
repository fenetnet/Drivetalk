-- DriveBond — weekly summary (1.2.1/1.2.3, owner 2026-11-03).
--
-- Friday morning: a note only to who talked with more than 3 different
-- people that week (owner; the app's "your week" card counts the same on
-- the phone). Nothing else changes; older apps ignore the new note.

-- ------------------------------------------------------------ weekly

-- Talks in the last 7 days: how many, and with how many different people.
create or replace function public.week_of(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'talks', count(*),
    'people', count(distinct case when o.user_a = p_user then o.user_b else o.user_a end))
  from match_offers o
  where p_user in (o.user_a, o.user_b)
    and o.talked
    and o.created_at >= now() - interval '7 days';
$$;
revoke all on function public.week_of(uuid) from public, anon, authenticated;

-- Friday morning: only who talked with more than 3 people this week.
create or replace function public.weekly_summary_tick()
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
  day text := to_char(now() at time zone 'Asia/Jerusalem', 'YYYYMMDD');
begin
  for r in
    select u.id, week_of(u.id) as w
    from (select distinct x.u as id from match_offers o
          cross join lateral (values (o.user_a), (o.user_b)) x(u)
          where o.talked and o.created_at >= now() - interval '7 days') u
  loop
    continue when (r.w ->> 'people')::int <= 3;
    perform push_queue(r.id, 'weekly', r.w, 'weekly:' || r.id || ':' || day);
  end loop;
end;
$$;
revoke all on function public.weekly_summary_tick() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('drivetalk-weekly')
    where exists (select 1 from cron.job where jobname = 'drivetalk-weekly');
    -- Friday 05:37 UTC = 07:37 / 08:37 in Israel.
    perform cron.schedule('drivetalk-weekly', '37 5 * * 5', 'select public.weekly_summary_tick()');
  end if;
end;
$$;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 72 $$;

insert into public.drivetalk_migrations (name)
values ('20261072000000_weekly_summary') on conflict do nothing;

notify pgrst, 'reload schema';
