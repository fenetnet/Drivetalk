-- DriveBond — "available to…" several groups, or everyone except some
-- (owner, D-156).
--
-- A free window still points at ONE circle (older apps keep working): the
-- choice becomes a hidden circle of mine whose members are the chosen
-- groups' people (or all my friends but theirs). It's rebuilt each time I
-- become free, never listed among my groups, and automatic trips use it.

alter table public.circles add column if not exists hidden boolean not null default false;
alter table public.profiles add column if not exists audience_circle uuid
  references public.circles(id) on delete set null;

-- My groups as the app lists them: never the hidden one.
alter policy circles_all on public.circles
  using (owner = (select auth.uid()) and not hidden)
  with check (owner = (select auth.uid()) and not hidden);

-- "Who sees me" rules (older apps) count only real groups, never the
-- hidden one.
create or replace function public.can_see(p_viewer uuid, p_owner uuid, p_mode text)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when exists (
      select 1 from circles c join circle_members m on m.circle_id = c.id
      where c.owner = p_owner and m.member = p_viewer and not c.hidden)
    then not exists (
      select 1 from circles c join circle_members m on m.circle_id = c.id
      where c.owner = p_owner and m.member = p_viewer and not c.hidden
        and c.show_modes is not null and not (p_mode = any (c.show_modes)))
    else coalesce((
      select o.show_modes is null or p_mode = any (o.show_modes)
      from others_visibility o where o.user_id = p_owner), true)
  end;
$$;
revoke all on function public.can_see(uuid, uuid, text) from public, anon, authenticated;

-- "Available to": [p_circles] (or everyone except them). Empty and not
-- "except" = everyone. Returns the circle to start with (null = everyone).
create or replace function public.set_audience(p_circles uuid[], p_except boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  chosen uuid[];
  aud uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select coalesce(array_agg(id), '{}') into chosen
  from circles where owner = me and not hidden and id = any(coalesce(p_circles, '{}'));
  if cardinality(chosen) = 0 and not coalesce(p_except, false) then
    update profiles set audience_circle = null where id = me;
    -- Already free: from now on for everyone.
    update availability set circle_id = null where user_id = me and expires_at > now();
    return null;
  end if;
  select id into aud from circles where owner = me and hidden limit 1;
  if aud is null then
    insert into circles (owner, name, hidden) values (me, '·audience', true)
    returning id into aud;
  end if;
  delete from circle_members where circle_id = aud;
  insert into circle_members (circle_id, member)
  select distinct aud, f from (
    select m.member as f from circle_members m
    where not coalesce(p_except, false) and m.circle_id = any(chosen)
    union all
    select f from friend_ids(me) f
    where coalesce(p_except, false)
      and not exists (select 1 from circle_members m
                      where m.circle_id = any(chosen) and m.member = f)) x
  where are_connected(me, x.f)
  on conflict do nothing;
  update profiles set audience_circle = aud where id = me;
  -- Already free: from now on for them.
  update availability set circle_id = aud where user_id = me and expires_at > now();
  return aud;
end;
$$;
revoke all on function public.set_audience(uuid[], boolean) from public, anon;
grant execute on function public.set_audience(uuid[], boolean) to authenticated;

create or replace function public.auto_start(p_token text, p_minutes integer default 120)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  mins integer := least(greatest(coalesce(p_minutes, 120), 15), 180);
  cur availability;
  same_trip boolean;
begin
  if me is null then return 'bad_token'; end if;
  select * into cur from availability where user_id = me and expires_at > now();
  if found and cur.source = 'manual' then
    return 'already_available';
  end if;
  same_trip := found and cur.source = 'auto'
    and cur.started_at > now() - interval '2 hours 50 minutes';
  if not same_trip and in_quiet_hours(me) then
    return 'quiet_hours';
  end if;
  insert into availability (user_id, mode, started_at, expires_at, source, quiet_until, circle_id)
  values (me, 'driving', now(), now() + make_interval(mins => mins), 'auto',
          now() + interval '5 minutes', (select audience_circle from profiles where id = me))
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
                           else now() + interval '5 minutes' end;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return 'available';
end;
$$;
revoke all on function public.auto_start(text, integer) from public;
grant execute on function public.auto_start(text, integer) to anon, authenticated;

-- "Until when" (owner: an exact time, also shorter): same window, a new
-- end — at least 5 minutes from now, at most 3 hours from its start.
create or replace function public.set_until(p_until timestamptz)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  until timestamptz;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_until is null then raise exception 'invalid_minutes'; end if;
  update availability
  set expires_at = least(greatest(p_until, now() + interval '5 minutes'),
                         started_at + interval '3 hours')
  where user_id = auth.uid() and expires_at > now() and source = 'manual'
  returning expires_at into until;
  return until;
end;
$$;
revoke all on function public.set_until(timestamptz) from public, anon;
grant execute on function public.set_until(timestamptz) to authenticated;

-- Last: the version says 66 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 66 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261066000000_available_to_groups') on conflict do nothing;

notify pgrst, 'reload schema';
