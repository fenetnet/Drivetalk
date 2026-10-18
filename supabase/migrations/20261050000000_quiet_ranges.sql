-- DriveBond — several quiet-hours schedules (D-124, owner: e.g. Sunday to
-- Thursday nights, and other hours on Friday and Saturday).
--
-- profiles.quiet_ranges: up to 4 ranges [{"f": from, "t": to, "d": days}]
-- (minutes after midnight; days = a bit per day, Sunday = 1 … Saturday =
-- 64; no "d" = every day). Hours across midnight belong to the day they
-- start. Null = the older single range (quiet_from / quiet_to /
-- quiet_days), which apps up to build 150 still set; when they do, it
-- replaces the list. The first range is also copied to those columns so
-- those apps show something sensible.

alter table public.profiles add column if not exists quiet_ranges jsonb;

-- Is [p_at] (local time) inside one range?
create or replace function public.quiet_range_now(
  p_from integer, p_to integer, p_days integer, p_at timestamp)
returns boolean language sql immutable as $$
  with t as (
    select (extract(hour from p_at) * 60 + extract(minute from p_at))::int as m,
           extract(dow from p_at)::int as d),
  w as (
    select case
      when p_from is null or p_to is null or p_from = p_to then null
      when p_from < p_to then case when t.m >= p_from and t.m < p_to then t.d end
      when t.m >= p_from then t.d
      when t.m < p_to then (t.d + 6) % 7
    end as day
    from t)
  select w.day is not null
         and (p_days is null or (p_days & (1 << w.day)) <> 0)
  from w;
$$;
revoke all on function public.quiet_range_now(integer, integer, integer, timestamp) from public, anon, authenticated;

-- My ranges (the list, or the older single range), as a list.
create or replace function public.quiet_list(p profiles)
returns jsonb language sql stable as $$
  select case
    when p.quiet_ranges is not null then p.quiet_ranges
    when p.quiet_from is null or p.quiet_to is null or p.quiet_from = p.quiet_to then '[]'::jsonb
    else jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'f', p.quiet_from, 't', p.quiet_to, 'd', p.quiet_days)))
  end;
$$;
revoke all on function public.quiet_list(profiles) from public, anon, authenticated;

create or replace function public.in_quiet_hours(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select bool_or(quiet_range_now(
      (r->>'f')::int, (r->>'t')::int, (r->>'d')::int,
      now() at time zone p.time_zone))
    from profiles p, jsonb_array_elements(quiet_list(p)) r
    where p.id = p_user), false);
$$;
revoke all on function public.in_quiet_hours(uuid) from public, anon, authenticated;

-- Save the whole list (empty = no quiet hours).
create or replace function public.set_quiet_ranges(p_ranges jsonb, p_time_zone text default null)
returns text language plpgsql security definer set search_path = public as $$
declare
  clean jsonb := '[]'::jsonb;
  r jsonb;
  f int;
  t int;
  d int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if jsonb_typeof(p_ranges) is distinct from 'array' or jsonb_array_length(p_ranges) > 4 then
    return 'bad';
  end if;
  for r in select * from jsonb_array_elements(p_ranges) loop
    begin
      f := (r->>'f')::int;
      t := (r->>'t')::int;
      d := (r->>'d')::int;
    exception when others then
      return 'bad';
    end;
    if f is null or t is null or f not between 0 and 1439 or t not between 0 and 1439
       or f = t then
      return 'bad';
    end if;
    if d is not null and (d <= 0 or d >= 127) then d := null; end if;
    clean := clean || jsonb_build_array(jsonb_strip_nulls(
      jsonb_build_object('f', f, 't', t, 'd', d)));
  end loop;
  if p_time_zone is not null and not exists (
    select 1 from pg_timezone_names where name = p_time_zone) then
    p_time_zone := null;
  end if;
  update profiles set
    quiet_ranges = clean,
    -- For older apps: the first range.
    quiet_from = (clean->0->>'f')::smallint,
    quiet_to = (clean->0->>'t')::smallint,
    quiet_days = (clean->0->>'d')::smallint,
    time_zone = coalesce(p_time_zone, time_zone)
  where id = auth.uid();
  return 'ok';
end;
$$;
revoke all on function public.set_quiet_ranges(jsonb, text) from public, anon;
grant execute on function public.set_quiet_ranges(jsonb, text) to authenticated;

-- Older apps set one range: it replaces the list.
create or replace function public.set_settings(
  p_anonymous boolean default null,
  p_hide_in_call boolean default null,
  p_quiet_from integer default null,
  p_quiet_to integer default null,
  p_clear_quiet boolean default false,
  p_time_zone text default null,
  p_quiet_days integer default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_time_zone is not null and not exists (
    select 1 from pg_timezone_names where name = p_time_zone) then
    p_time_zone := null;
  end if;
  update profiles set
    anonymous = coalesce(p_anonymous, anonymous),
    hide_in_call = coalesce(p_hide_in_call, hide_in_call),
    quiet_from = case when p_clear_quiet then null
                      else coalesce(p_quiet_from, quiet_from) end,
    quiet_to = case when p_clear_quiet then null
                    else coalesce(p_quiet_to, quiet_to) end,
    quiet_days = case when p_clear_quiet then null
                      when p_quiet_days is null then quiet_days
                      when p_quiet_days <= 0 or p_quiet_days >= 127 then null
                      else p_quiet_days end,
    quiet_ranges = case when p_clear_quiet
                          or p_quiet_from is not null or p_quiet_to is not null
                          or p_quiet_days is not null then null
                        else quiet_ranges end,
    time_zone = coalesce(p_time_zone, time_zone)
  where id = auth.uid();
end;
$$;
revoke all on function public.set_settings(boolean, boolean, integer, integer, boolean, text, integer) from public, anon;
grant execute on function public.set_settings(boolean, boolean, integer, integer, boolean, text, integer) to authenticated;

create or replace function public.my_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  p profiles;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into p from profiles where id = me;
  return jsonb_build_object(
    'anonymous', p.anonymous,
    'hide_in_call', p.hide_in_call,
    'quiet_from', p.quiet_from,
    'quiet_to', p.quiet_to,
    'quiet_days', p.quiet_days,
    'quiet_ranges', quiet_list(p),
    'auto_missed', p.auto_missed,
    'trip_notify', p.trip_notify,
    -- free friends I can't see by name (theirs or my "without my name")
    'hidden_free', (
      select count(*) from availability a
      where a.user_id <> me
        and sees_free_apart_from_name(me, a)
        and (is_anonymous(a.user_id) or p.anonymous)
        and not coalesce(a.call_until > now() or a.phone_until > now(), false)),
    -- friends who added me from their contacts and wait for me to keep them
    'pending', coalesce((
      select jsonb_agg(case when c.user_a = me then c.user_b else c.user_a end)
      from connections c
      where c.pending_for = me), '[]'::jsonb));
end;
$$;
revoke all on function public.my_status() from public, anon;
grant execute on function public.my_status() to authenticated;

-- Last: the version says 50 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 50 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261050000000_quiet_ranges') on conflict do nothing;
