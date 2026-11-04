-- DriveBond — after a call (D-142, owner: his wife stayed grey after their
-- call and couldn't be asked again).
--
-- 1. A call is over once EITHER side closed it ("how was it?" answered, or
--    the phone said the call ended). Before, each side stayed "in a call"
--    until they closed it themselves (up to 20 minutes), and a friend
--    couldn't ask again until BOTH had — whatever availability they set.
-- 2. The app no longer suggests the same two people again by itself for an
--    hour after they talked (was 30 minutes). Tapping a friend still works.
-- 3. ask_why(friend): why a free friend can't be asked right now, for the
--    note on the grey circle ("your last call isn't closed yet"…).

create or replace function public.in_call(p_user uuid, p_except uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_offers o
    where o.status = 'accepted'
      and o.id is distinct from p_except
      and o.accepted_at > now() - interval '20 minutes'
      and not (o.quick and o.not_before is null and o.accepted_at < now() - interval '2 minutes')
      and not (o.quick and o.caller is null and o.not_before is not null
               and o.not_before < now() - interval '2 minutes')
      and p_user in (o.user_a, o.user_b)
      -- Over once either of us closed it (D-142; before: my own side).
      and not o.ended_a and not o.ended_b
  );
$$;
revoke all on function public.in_call(uuid, uuid) from public, anon, authenticated;

create or replace function public.mark_app_call()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted'
     and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
    update availability
    set call_until = now() + case when new.quick and new.not_before is null
                                  then interval '2 minutes' else interval '20 minutes' end
    where user_id in (new.user_a, new.user_b);
    update match_offers set talked = coalesce(talked, true) where id = new.id;
    insert into pair_snoozes (from_user, to_user, until)
    values (new.user_a, new.user_b, now() + interval '3 days'),
           (new.user_b, new.user_a, now() + interval '3 days')
    on conflict (from_user, to_user)
    do update set until = greatest(pair_snoozes.until, excluded.until),
                  -- the automatic 3 days took over a shorter chosen pause
                  chosen = pair_snoozes.chosen and pair_snoozes.until >= excluded.until;
  end if;
  if tg_op = 'UPDATE' then
    if new.status = 'accepted' and new.quick
       and new.not_before is not null and old.not_before is null then
      update availability set call_until = now() + interval '20 minutes'
      where user_id in (new.user_a, new.user_b);
    end if;
    if old.status = 'accepted' and new.status <> 'accepted' then
      update availability set call_until = null where user_id in (new.user_a, new.user_b);
      update match_offers set talked = null where id = new.id;
      -- Cancelled before it began (quick connect's 5 seconds): no pause.
      delete from pair_snoozes
      where ((from_user = new.user_a and to_user = new.user_b)
             or (from_user = new.user_b and to_user = new.user_a))
        and until <= coalesce(new.accepted_at, now()) + interval '3 days 1 minute';
    end if;
    -- Either of us closed it: the call is over for both (D-142).
    if (new.ended_a and not old.ended_a) or (new.ended_b and not old.ended_b) then
      update availability set call_until = null
      where user_id in (new.user_a, new.user_b)
        and not in_call(user_id, new.id);
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.mark_app_call() from public, anon, authenticated;

create or replace function public.ask_check(p_me uuid, p_user uuid, p_me_free boolean)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  theirs availability;
  lo uuid := least(p_me, p_user);
  hi uuid := greatest(p_me, p_user);
begin
  if p_me_free and not exists (
    select 1 from availability where user_id = p_me and expires_at > now()) then
    return 'me_not_free';
  end if;
  select * into theirs from availability where user_id = p_user;
  if not found or p_user = p_me
     or not sees_free_apart_from_name(p_me, theirs)
     or is_anonymous(p_user) or is_anonymous(p_me)
     or pair_pending(p_me, p_user)
     or rating_of(p_user, p_me) = 0 then
    return 'not_free';
  end if;
  if not exists (select 1 from phone_numbers n where n.user_id in (p_me, p_user)) then
    return 'no_number';
  end if;
  if not can_be_asked(p_user) or asked_enough(p_user, theirs.started_at) then
    return 'busy';
  end if;
  if exists (
    select 1 from match_offers o
    where o.user_a = lo and o.user_b = hi
      and (-- they already said no to us this time
           (o.status = 'declined'
               and (case when p_user = o.user_a then o.a_response else o.b_response end)
                   = 'decline'
               and o.created_at >= theirs.started_at))) then
    return 'not_now';
  end if;
  -- Our call is still on: over once EITHER of us closed it ("how was
  -- it?", or the phone call ended) — before, both had to (D-142).
  if exists (
    select 1 from match_offers o
    where o.user_a = lo and o.user_b = hi
      and o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes'
      and not o.ended_a and not o.ended_b) then
    return 'call_open';
  end if;
  return 'ok';
end;
$$;
revoke all on function public.ask_check(uuid, uuid, boolean) from public, anon, authenticated;

create or replace function public.create_offers_for(p_user uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  other record;
  lo uuid;
  hi uuid;
  quick boolean;
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
    quick := is_quick(p_user, other.user_id) and is_quick(other.user_id, p_user)
      and not exists (
        select 1 from match_offers o
        where o.user_a = lo and o.user_b = hi and o.quick
          and o.created_at > now() - interval '1 day')
      and not exists (
        select 1 from match_offers o
        where o.quick and p_user in (o.user_a, o.user_b) and o.created_at >= mine.started_at)
      and not exists (
        select 1 from match_offers o
        where o.quick and other.user_id in (o.user_a, o.user_b) and o.created_at >= other.started_at);
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
      insert into match_offers (user_a, user_b, expires_at, shared_until, last_talk)
      values (lo, hi, least(mine.expires_at, other.expires_at, now() + interval '2 minutes'),
              -- an automatic trip's end isn't known: only real times count
              case
                when mine.source = 'manual' and other.source = 'manual'
                  then least(mine.expires_at, other.expires_at)
                when mine.source = 'manual' then mine.expires_at
                when other.source = 'manual' then other.expires_at
              end,
              other.last_talk)
      on conflict do nothing;
    end if;
    return 1;
  end loop;
  return 0;
end;
$$;

-- Clear the leftovers of calls one side already closed.
update public.availability a set call_until = null
where a.call_until > now() and not public.in_call(a.user_id);

create or replace function public.ask_why(p_user uuid)
returns text language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not are_connected(auth.uid(), p_user) then return 'not_free'; end if;
  return ask_check(auth.uid(), p_user, false);
end;
$$;
revoke all on function public.ask_why(uuid) from public, anon;
grant execute on function public.ask_why(uuid) to authenticated;

-- Last: the version says 59 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 59 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261059000000_call_over_either_side') on conflict do nothing;
