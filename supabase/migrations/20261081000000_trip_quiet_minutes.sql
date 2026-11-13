-- DriveBond — "free to talk how long after a trip starts" (owner,
-- 2026-11-11). Until now every automatic trip had 5 quiet minutes first
-- (D-106). Now each person chooses in Settings: right away (0) up to a
-- quarter of an hour (15); 5 stays the default. Only for automatic trips.
-- Changing it during the quiet minutes of the current trip applies at once.
-- Older apps: nothing changes (5 minutes, as before).

alter table public.profiles
  add column if not exists trip_quiet_minutes smallint not null default 5
  check (trip_quiet_minutes between 0 and 15);

create or replace function public.set_trip_quiet(p_minutes integer)
returns integer language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_minutes is null or p_minutes < 0 or p_minutes > 15 then
    raise exception 'invalid';
  end if;
  update profiles set trip_quiet_minutes = p_minutes where id = me;
  -- In the quiet minutes of a trip right now: the new choice counts.
  update availability
  set quiet_until = started_at + make_interval(mins => p_minutes)
  where user_id = me and source = 'auto' and quiet_until > now();
  perform create_offers_for(me);
  return p_minutes;
end;
$$;
revoke all on function public.set_trip_quiet(integer) from public, anon;
grant execute on function public.set_trip_quiet(integer) to authenticated;

create or replace function public.auto_start(p_token text, p_minutes integer default 120)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  mins integer := least(greatest(coalesce(p_minutes, 120), 15), 180);
  cur availability;
  same_trip boolean;
  quiet integer;
begin
  if me is null then return 'bad_token'; end if;
  select coalesce(trip_quiet_minutes, 5) into quiet from profiles where id = me;
  quiet := coalesce(quiet, 5);
  select * into cur from availability where user_id = me and expires_at > now();
  if found and cur.source = 'manual' then
    return 'already_available';
  end if;
  same_trip := found and cur.source = 'auto'
    and cur.started_at > now() - interval '2 hours 50 minutes';
  if not same_trip and in_quiet_hours(me) then
    return 'quiet_hours';
  end if;
  -- The groups as they are now, not as they were when I chose (D-164).
  perform rebuild_audience(me);
  insert into availability (user_id, mode, started_at, expires_at, source, quiet_until, circle_id)
  values (me, 'driving', now(), now() + make_interval(mins => mins), 'auto',
          now() + make_interval(mins => quiet), (select audience_circle from profiles where id = me))
  on conflict (user_id) do update
    set mode = 'driving',
        started_at = case when same_trip then availability.started_at else now() end,
        expires_at = least(
          now() + make_interval(mins => mins),
          case when same_trip then availability.started_at else now() end + interval '3 hours'),
        source = 'auto',
        -- A trip is for the groups I last chose ("available to…", D-156),
        -- never the group of an earlier free window.
        circle_id = (select audience_circle from profiles where id = me),
        missed_at = case when same_trip then availability.missed_at end,
        quiet_until = case when same_trip then availability.quiet_until
                           else now() + make_interval(mins => quiet) end;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return 'available';
end;
$$;

create or replace function public.auto_yes_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'on', (select auto_yes from profiles where id = me),
    'min', (select auto_yes_min from profiles where id = me),
    -- Free to talk this many minutes after a trip starts (server 81).
    'trip_quiet', (select trip_quiet_minutes from profiles where id = me),
    'instant', coalesce((
      select jsonb_agg(a.user_id)
      from connections c
      join availability a
        on a.user_id = case when c.user_a = me then c.user_b else c.user_a end
      join profiles p on p.id = a.user_id and p.auto_yes
      where me in (c.user_a, c.user_b) and c.pending_for is null
        and not is_anonymous(me)
        and a.mode = 'driving' and a.expires_at > now()
        -- Only friends I may see as free right now (D-164).
        and not hides_status(a.user_id)
        and not is_anonymous(a.user_id)
        and sees_free_apart_from_name(me, a)
        -- The first minutes of a trip a tap gets "busy": no ring then.
        and (a.quiet_until is null or a.quiet_until <= now())
        and auto_yes_for(a.user_id, me)), '[]'::jsonb));
end;
$$;

-- Last: the version says 81 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 81 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261081000000_trip_quiet_minutes') on conflict do nothing;

notify pgrst, 'reload schema';
