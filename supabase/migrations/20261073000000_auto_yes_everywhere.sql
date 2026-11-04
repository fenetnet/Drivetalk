-- DriveBond — ⚡ "yes automatically" really means yes (owner, 2026-11-04).
--
-- 1. In every mode, not only while driving ("I have time", walking, a
--    break). Still only for friends with enough stars (my choice: 3, 4 or
--    5), and never in quiet hours, in a call, or with a pause I chose.
-- 2. When the app itself suggests a talk, the ⚡ side is not asked at all:
--    its "yes" is already in. Only the other side is asked; their "yes"
--    makes the ⚡ phone ring like any call (they dial).
--    Tapping a ⚡ friend works as before (connected at once), also while
--    the app's question is open.
-- 3. If they don't answer, they are not told "X tried to reach you" — X
--    did nothing; ⚡ answered for them.
-- Older apps: nothing to update. An app that is open may show "waiting for
-- X" instead of the question.

alter table public.match_offers add column if not exists auto_accepted uuid;

-- ------------------------------------------------------------ 1. every mode

create or replace function public.auto_yes_for(p_user uuid, p_from uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p join availability a on a.user_id = p.id
    where p.id = p_user and p.auto_yes
      and a.expires_at > now() and a.missed_at is null
      and rating_of(p_user, p_from) >= p.auto_yes_min)
    and exists (select 1 from phone_numbers where user_id = p_user)
    and are_connected(p_user, p_from)
    and not awaits_approval(p_user, p_from)
    and not exists (select 1 from pair_snoozes z
                    where z.chosen and z.until > now()
                      and z.from_user = p_user and z.to_user = p_from)
    and not is_blocked_between(p_user, p_from)
    and not in_call(p_user)
    and not on_phone(p_user)
    and not in_quiet_hours(p_user);
$$;
revoke all on function public.auto_yes_for(uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ 2. only they are asked

create or replace function public.create_offers_for(p_user uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  other record;
  lo uuid;
  hi uuid;
  quick boolean;
  auto_mine boolean;
  auto_theirs boolean;
  auto_side uuid;
begin
  -- One at a time across everyone: no two offers race for the same person.
  perform pg_advisory_xact_lock(727274);
  update match_offers set status = 'expired', updated_at = expires_at
  where status = 'pending' and expires_at <= now();
  select * into mine from availability where user_id = p_user and expires_at > now();
  if not found then return 0; end if;
  if not can_be_asked(p_user) then return 0; end if;
  if quiet_gap(p_user) or asked_enough(p_user, mine.started_at) then return 0; end if;

  for other in
    select a.user_id, a.expires_at, a.circle_id, a.started_at, a.mode, a.source,
           (select max(o.accepted_at) from match_offers o
            where o.status = 'accepted' and o.talked
              and o.user_a = least(p_user, a.user_id)
              and o.user_b = greatest(p_user, a.user_id)) as last_talk
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and c.pending_for is null
      and not is_blocked_between(p_user, a.user_id)
      and rating_of(p_user, a.user_id) > 0
      and rating_of(a.user_id, p_user) > 0
      -- A pause after a call stops suggestions — but quick-connect
      -- friends only by a pause someone chose (D-113); for them the
      -- automatic pause is checked below, once it's known if it's quick.
      and not exists (
        select 1 from pair_snoozes z
        where z.until > now()
          and ((z.from_user = p_user and z.to_user = a.user_id)
               or (z.from_user = a.user_id and z.to_user = p_user))
          and (z.chosen
               or not (is_quick(p_user, a.user_id) and is_quick(a.user_id, p_user))))
    -- Quick-connect friends first, then friends who show their name
    -- (D-103), then how much both want to talk, then least recent talk.
    order by (is_quick(p_user, a.user_id) and is_quick(a.user_id, p_user)) desc,
             is_anonymous(a.user_id) asc,
             rating_of(p_user, a.user_id) + rating_of(a.user_id, p_user) desc,
             last_talk asc nulls first,
             random()
  loop
    if not in_audience(mine.circle_id, other.user_id)
       or not in_audience(other.circle_id, p_user)
       or not can_see(other.user_id, p_user, mine.mode)
       or not can_see(p_user, other.user_id, other.mode)
       or not exists (select 1 from phone_numbers n where n.user_id in (p_user, other.user_id))
       or not can_be_asked(other.user_id)
       or quiet_gap(other.user_id)
       or asked_enough(other.user_id, other.started_at) then
      continue;
    end if;
    lo := least(p_user, other.user_id);
    hi := greatest(p_user, other.user_id);
    if exists (
      select 1 from match_offers o
      where o.user_a = lo and o.user_b = hi
        and ((o.status = 'declined' and o.updated_at > now() - interval '2 minutes')
             -- After talking: not suggested again for an hour (owner, D-142).
             or (o.status = 'accepted' and o.accepted_at > now() - interval '60 minutes')
             or (o.status in ('declined', 'expired', 'cancelled')
                 and o.created_at >= greatest(mine.started_at, other.started_at)))
    ) then
      continue;
    end if;
    -- ⚡ on both sides: like quick connect (whoever starts calls), with no
    -- daily limit (owner, D-153).
    auto_mine := auto_yes_for(p_user, other.user_id);
    auto_theirs := auto_yes_for(other.user_id, p_user);
    quick := (auto_mine and auto_theirs)
      or (is_quick(p_user, other.user_id) and is_quick(other.user_id, p_user)
      and not exists (
        select 1 from match_offers o
        where o.user_a = lo and o.user_b = hi and o.quick
          and o.created_at > now() - interval '1 day')
      and not exists (
        select 1 from match_offers o
        where o.quick and p_user in (o.user_a, o.user_b) and o.created_at >= mine.started_at)
      and not exists (
        select 1 from match_offers o
        where o.quick and other.user_id in (o.user_a, o.user_b) and o.created_at >= other.started_at));
    -- The automatic pause lets only quick connect through: a regular
    -- question still waits for it to end (D-108).
    if not quick and exists (
      select 1 from pair_snoozes z
      where z.until > now()
        and ((z.from_user = p_user and z.to_user = other.user_id)
             or (z.from_user = other.user_id and z.to_user = p_user))
    ) then
      continue;
    end if;
    if quick then
      insert into match_offers (user_a, user_b, expires_at, status, a_response, b_response,
                                quick, accepted_at, last_talk)
      values (lo, hi, least(mine.expires_at, other.expires_at), 'accepted', 'accept', 'accept',
              true, now(), other.last_talk);
    else
      -- ⚡ on one side (owner, 2026-11-04): that side already said yes —
      -- only the other one is asked; their "yes" rings the ⚡ phone.
      auto_side := case when auto_mine then p_user when auto_theirs then other.user_id end;
      insert into match_offers (user_a, user_b, expires_at, shared_until, last_talk,
                                a_response, b_response, auto_accepted)
      values (lo, hi, least(mine.expires_at, other.expires_at, now() + interval '2 minutes'),
              -- an automatic trip's end isn't known: only real times count
              case
                when mine.source = 'manual' and other.source = 'manual'
                  then least(mine.expires_at, other.expires_at)
                when mine.source = 'manual' then mine.expires_at
                when other.source = 'manual' then other.expires_at
              end,
              other.last_talk,
              case when auto_side = lo then 'accept' end,
              case when auto_side = hi then 'accept' end,
              auto_side)
      on conflict do nothing;
    end if;
    return 1;
  end loop;
  return 0;
end;
$$;
revoke all on function public.create_offers_for(uuid) from public, anon, authenticated;

-- A tap while the app's question (answered only by ⚡) is open: the tap
-- replaces it, so the one who tapped calls, as always (D-145).
create or replace function public.ask_friend(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  mine availability;
  theirs availability;
  lo uuid;
  hi uuid;
  why text;
  new_id uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(727274);
  -- Only the friends I tapped count (not friends tapping me).
  if (select count(*) from match_offers o
      where o.direct and o.asked_by = me
        and o.created_at > now() - interval '1 hour') >= 10 then
    return 'rate_limited';
  end if;
  -- I'm clearly here: a question I missed earlier no longer hides me.
  update availability set missed_at = null
  where user_id = me and missed_at is not null;
  -- The app's own question between us (made a moment ago, nobody
  -- answered yet) gives way to my tap: my direct ask replaces it, so the
  -- one who tapped is the one who calls (D-145, D-147).
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and not quick and not direct
    and user_a = least(me, p_user) and user_b = greatest(me, p_user)
    and ((a_response is null and b_response is null)
         -- only ⚡ answered it for them (owner, 2026-11-04)
         or (auto_accepted = p_user
             and (case when me = user_a then a_response else b_response end) is null));
  why := ask_check(me, p_user, true);
  if why <> 'ok' then return why; end if;
  select * into mine from availability where user_id = me;
  select * into theirs from availability where user_id = p_user;
  lo := least(me, p_user);
  hi := greatest(me, p_user);
  -- My own open question (if any) gives way to this one.
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and me in (user_a, user_b);
  insert into match_offers (user_a, user_b, expires_at, shared_until, last_talk, direct,
                            a_response, b_response, asked_by)
  values (lo, hi, least(mine.expires_at, theirs.expires_at, now() + interval '2 minutes'),
          case
            when mine.source = 'manual' and theirs.source = 'manual'
              then least(mine.expires_at, theirs.expires_at)
            when mine.source = 'manual' then mine.expires_at
            when theirs.source = 'manual' then theirs.expires_at
          end,
          (select max(o.accepted_at) from match_offers o
           where o.status = 'accepted' and o.talked and o.user_a = lo and o.user_b = hi),
          true,
          case when me = lo then 'accept' end,
          case when me = hi then 'accept' end,
          me)
  returning id into new_id;
  -- They said yes ahead of time for me while driving: connected now, and
  -- I call (D-153).
  if auto_yes_for(p_user, me) then
    perform answer_offer_as(p_user, new_id, true);
  end if;
  return 'asked';
end;
$$;
revoke all on function public.ask_friend(uuid) from public, anon;
grant execute on function public.ask_friend(uuid) to authenticated;

-- ------------------------------------------------------------ 3. no "tried to reach you"

create or replace function public.missed_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  side record;
begin
  if new.status in ('declined', 'expired', 'cancelled')
     and old.status = 'pending' and not new.quick then
    for side in
      select new.user_a as me, new.user_b as other
      where new.a_response is null and new.b_response = 'accept'
      union all
      select new.user_b, new.user_a
      where new.b_response is null and new.a_response = 'accept'
    loop
      continue when in_quiet_hours(side.me);
      -- ⚡ said yes for them; they didn't try anything themselves.
      continue when new.auto_accepted is not distinct from side.other;
      perform push_queue(side.me, 'missed',
        (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
         from profiles p where p.id = side.other),
        'missed:' || side.me || ':' || (
          select to_char(now() at time zone coalesce(p.time_zone, 'Asia/Jerusalem'), 'YYYYMMDD')
          from profiles p where p.id = side.me));
    end loop;
  end if;
  return null;
end;
$$;
revoke all on function public.missed_push() from public, anon, authenticated;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 73 $$;

insert into public.drivetalk_migrations (name)
values ('20261073000000_auto_yes_everywhere') on conflict do nothing;

notify pgrst, 'reload schema';
