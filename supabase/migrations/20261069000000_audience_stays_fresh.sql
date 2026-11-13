-- DriveBond — "available to…" stays right (review 2026-10-30, D-164).
--
-- The hidden "·audience" circle (66) was a copy made when I chose: a
-- group changed later, or a new friend, and automatic trips still went to
-- the old copy (someone removed from "family" kept seeing me; with
-- "everyone except…" a new friend never did). Now the choice itself is
-- kept on my profile and the copy is rebuilt whenever a group or a
-- friendship changes, and before every automatic trip.
-- Older apps: same functions and answers.

alter table public.profiles
  add column if not exists audience_ids uuid[],
  add column if not exists audience_except boolean not null default false;

-- Rebuild my hidden audience circle from the stored choice. Nothing to do
-- for "everyone", or for a choice made before this version (no ids kept).
create or replace function public.rebuild_audience(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  aud uuid;
  ids uuid[];
  exc boolean;
begin
  select audience_circle, audience_ids, audience_except into aud, ids, exc
  from profiles where id = p_user;
  if aud is null or ids is null then return; end if;
  delete from circle_members where circle_id = aud;
  insert into circle_members (circle_id, member)
  select distinct aud, f from (
    select m.member as f from circle_members m
    join circles c on c.id = m.circle_id and c.owner = p_user and not c.hidden
    where not exc and m.circle_id = any(ids)
    union all
    select f from friend_ids(p_user) f
    where exc
      and not exists (select 1 from circle_members m
                      join circles c on c.id = m.circle_id and c.owner = p_user
                      where m.circle_id = any(ids) and m.member = f)) x
  where are_connected(p_user, x.f)
  on conflict do nothing;
end;
$$;
revoke all on function public.rebuild_audience(uuid) from public, anon, authenticated;

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
    update profiles set audience_circle = null, audience_ids = null,
                        audience_except = false where id = me;
    -- Already free: from now on for everyone.
    update availability set circle_id = null where user_id = me and expires_at > now();
    return null;
  end if;
  select id into aud from circles where owner = me and hidden limit 1;
  if aud is null then
    insert into circles (owner, name, hidden) values (me, '·audience', true)
    returning id into aud;
  end if;
  update profiles set audience_circle = aud, audience_ids = chosen,
                      audience_except = coalesce(p_except, false)
  where id = me;
  perform rebuild_audience(me);
  -- Already free: from now on for them.
  update availability set circle_id = aud where user_id = me and expires_at > now();
  return aud;
end;
$$;
revoke all on function public.set_audience(uuid[], boolean) from public, anon;
grant execute on function public.set_audience(uuid[], boolean) to authenticated;

-- A group I chose changed: my audience follows.
create or replace function public.audience_follow_members()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  cid uuid := coalesce(new.circle_id, old.circle_id);
  owner_id uuid;
begin
  if pg_trigger_depth() > 1 then return null; end if;
  select c.owner into owner_id from circles c where c.id = cid and not c.hidden;
  if owner_id is null then return null; end if;
  if exists (select 1 from profiles p
             where p.id = owner_id and p.audience_circle is not null
               and (p.audience_except or cid = any(coalesce(p.audience_ids, '{}')))) then
    perform rebuild_audience(owner_id);
  end if;
  return null;
end;
$$;
revoke all on function public.audience_follow_members() from public, anon, authenticated;
drop trigger if exists audience_follow_members on public.circle_members;
create trigger audience_follow_members
  after insert or delete on public.circle_members
  for each row execute function public.audience_follow_members();

-- A friendship began or ended: both audiences follow ("everyone
-- except…" includes a new friend).
create or replace function public.audience_follow_friends()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if pg_trigger_depth() > 1 then return null; end if;
  perform rebuild_audience(coalesce(new.user_a, old.user_a));
  perform rebuild_audience(coalesce(new.user_b, old.user_b));
  return null;
end;
$$;
revoke all on function public.audience_follow_friends() from public, anon, authenticated;
drop trigger if exists audience_follow_friends on public.connections;
create trigger audience_follow_friends
  after insert or delete or update of pending_for on public.connections
  for each row execute function public.audience_follow_friends();

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
  -- The groups as they are now, not as they were when I chose (D-164).
  perform rebuild_audience(me);
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

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 69 $$;

insert into public.drivetalk_migrations (name)
values ('20261069000000_audience_stays_fresh') on conflict do nothing;

notify pgrst, 'reload schema';
