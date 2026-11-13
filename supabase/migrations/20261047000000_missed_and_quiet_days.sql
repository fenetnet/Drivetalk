-- DriveBond — "X tried to reach you", no questions during a phone call,
-- quiet hours on chosen days (D-121).
--
-- - A question that ended without my answer, while the other side had said
--   yes (tapped me, or said yes to the app's question): one note for me,
--   "X tried to reach you". Not for quick connect (both see its countdown).
-- - A phone call starts: every open question of mine is closed (whoever
--   said yes to it gets the note above).
-- - Quiet hours can be limited to some days of the week (e.g. weekends):
--   a bit per day, Sunday = 1 … Saturday = 64; none = every day. Hours that
--   cross midnight belong to the day they start.
-- Older apps keep working: every new argument has a default.

-- ------------------------------------------------------------ missed

create or replace function public.missed_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status in ('declined', 'expired', 'cancelled')
     and old.status = 'pending' and not new.quick then
    if new.a_response is null and new.b_response = 'accept' then
      perform push_queue(new.user_a, 'missed',
        (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
         from profiles p where p.id = new.user_b),
        'missed:' || new.id || ':' || new.user_a);
    end if;
    if new.b_response is null and new.a_response = 'accept' then
      perform push_queue(new.user_b, 'missed',
        (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
         from profiles p where p.id = new.user_a),
        'missed:' || new.id || ':' || new.user_b);
    end if;
  end if;
  return null;
end;
$$;
revoke all on function public.missed_push() from public, anon, authenticated;
drop trigger if exists missed_push on public.match_offers;
create trigger missed_push after update of status on public.match_offers
  for each row execute function public.missed_push();

-- ------------------------------------------------------------ phone call

-- "In a call" from the phone: friends see it, and my open questions close.
create or replace function public.device_phone_call(p_token text, p_on boolean)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return 'bad_token'; end if;
  update availability
  set phone_until = case when p_on then now() + interval '3 minutes' else null end
  where user_id = me;
  if p_on then
    update match_offers set status = 'cancelled', updated_at = now()
    where status = 'pending' and me in (user_a, user_b);
  end if;
  return 'ok';
end;
$$;
revoke all on function public.device_phone_call(text, boolean) from public;
grant execute on function public.device_phone_call(text, boolean) to anon, authenticated;

-- ------------------------------------------------------------ quiet days

alter table public.profiles
  add column if not exists quiet_days smallint check (quiet_days between 1 and 127);

create or replace function public.in_quiet_hours(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select case
      when p.quiet_from is null or p.quiet_to is null or p.quiet_from = p.quiet_to then false
      else (
        with t as (
          select (extract(hour from l) * 60 + extract(minute from l))::int as m,
                 extract(dow from l)::int as d
          from (select now() at time zone p.time_zone as l) x),
        w as (
          -- inside the hours, and on which day they started
          select case when p.quiet_from < p.quiet_to
                        then case when t.m >= p.quiet_from and t.m < p.quiet_to then t.d end
                      when t.m >= p.quiet_from then t.d
                      when t.m < p.quiet_to then (t.d + 6) % 7
                 end as day
          from t)
        select w.day is not null
               and (p.quiet_days is null or (p.quiet_days & (1 << w.day)::smallint) <> 0)
        from w)
    end
    from profiles p where p.id = p_user), false);
$$;
revoke all on function public.in_quiet_hours(uuid) from public, anon, authenticated;

-- Same as before plus the days (0 or 127 = every day).
drop function if exists public.set_settings(boolean, boolean, integer, integer, boolean, text);
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

-- Last: the version says 47 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 47 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261047000000_missed_and_quiet_days') on conflict do nothing;
