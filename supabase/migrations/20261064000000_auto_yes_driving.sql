-- DriveBond — "yes automatically while driving" (owner, D-153).
--
-- A switch (off by default) and a star level (3, 4 or 5). While I'm in a
-- trip, a friend I gave at least that many stars who taps me, or says yes
-- to the app's question about me, is connected at once: they call me, my
-- phone just rings. When both of us have it on for each other, the app's
-- own suggestion connects by itself like quick connect: 5 seconds either
-- can cancel, then whoever starts calls. No daily limit.
-- Only when I have a number (I never dial by myself while driving), not
-- in a call or on the phone, not in quiet hours.

alter table public.profiles
  add column if not exists auto_yes boolean not null default false,
  add column if not exists auto_yes_min smallint not null default 3
    check (auto_yes_min between 1 and 5);

create or replace function public.auto_yes_for(p_user uuid, p_from uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p join availability a on a.user_id = p.id
    where p.id = p_user and p.auto_yes
      and a.mode = 'driving' and a.expires_at > now() and a.missed_at is null
      and rating_of(p_user, p_from) >= p.auto_yes_min)
    and exists (select 1 from phone_numbers where user_id = p_user)
    and are_connected(p_user, p_from)
    and not is_blocked_between(p_user, p_from)
    and not in_call(p_user)
    and not on_phone(p_user)
    and not in_quiet_hours(p_user);
$$;
revoke all on function public.auto_yes_for(uuid, uuid) from public, anon, authenticated;

create or replace function public.set_auto_yes(p_on boolean, p_min integer default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update profiles set
    auto_yes = coalesce(p_on, auto_yes),
    auto_yes_min = case when p_min between 1 and 5 then p_min else auto_yes_min end
  where id = auth.uid();
end;
$$;
revoke all on function public.set_auto_yes(boolean, integer) from public, anon;
grant execute on function public.set_auto_yes(boolean, integer) to authenticated;

-- My switch, my star level, and the friends who'd say yes to me right now
-- (only friends I gave enough stars ever learn it, by the double ring).
create or replace function public.auto_yes_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'on', (select auto_yes from profiles where id = me),
    'min', (select auto_yes_min from profiles where id = me),
    'instant', coalesce((
      select jsonb_agg(a.user_id)
      from connections c
      join availability a
        on a.user_id = case when c.user_a = me then c.user_b else c.user_a end
      join profiles p on p.id = a.user_id and p.auto_yes
      where me in (c.user_a, c.user_b) and c.pending_for is null
        and a.mode = 'driving' and a.expires_at > now()
        and auto_yes_for(a.user_id, me)), '[]'::jsonb));
end;
$$;
revoke all on function public.auto_yes_status() from public, anon;
grant execute on function public.auto_yes_status() to authenticated;

create or replace function public.answer_offer_as(p_me uuid, p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  pref uuid;
  callee uuid;
  me uuid := p_me;
  other uuid;
  o match_offers;
  answer text := case when p_accept then 'accept' else 'decline' end;
  withdrawn boolean;
begin
  if me is null then return jsonb_build_object('status', 'not_found'); end if;
  perform pg_advisory_xact_lock(727274);
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then
    return jsonb_build_object('status', 'not_found');
  end if;
  if o.status <> 'pending' then
    return jsonb_build_object(
      'status', o.status,
      'i_call', o.caller = me,
      'phone', case when o.status = 'accepted' and o.caller = me and now() >= o.not_before
                     and o.accepted_at > now() - interval '30 minutes'
                     and are_connected(o.user_a, o.user_b)
                    then call_phone_for(o, me) end);
  end if;
  if o.expires_at <= now()
     or not are_connected(o.user_a, o.user_b)
     or not exists (select 1 from availability where user_id = o.user_a and expires_at > now())
     or not exists (select 1 from availability where user_id = o.user_b and expires_at > now()) then
    update match_offers set status = 'expired', updated_at = now() where id = o.id;
    return jsonb_build_object('status', 'expired');
  end if;

  withdrawn := answer = 'decline'
    and coalesce((case when me = o.user_a then o.a_response else o.b_response end) = 'accept',
                 false);
  if not withdrawn then
    if me = o.user_a then o.a_response := answer; else o.b_response := answer; end if;
  end if;
  -- "Yes automatically while driving" (owner, D-153): a friend who said
  -- yes ahead of time for me is a yes now — I'm the one who calls.
  if answer = 'accept' then
    other := case when me = o.user_a then o.user_b else o.user_a end;
    if (case when other = o.user_a then o.a_response else o.b_response end) is null
       and auto_yes_for(other, me) then
      if other = o.user_a then o.a_response := 'accept'; else o.b_response := 'accept'; end if;
    end if;
  end if;

  if answer = 'decline' then
    o.status := 'declined';
  elsif o.a_response = 'accept' and o.b_response = 'accept' then
    if in_call(o.user_a, o.id) or in_call(o.user_b, o.id) then
      -- Both said yes, but one is in another call: keep the answers, so
      -- nobody is marked "didn't answer".
      update match_offers
        set status = 'expired', a_response = o.a_response, b_response = o.b_response,
            updated_at = now()
      where id = o.id;
      return jsonb_build_object('status', 'expired');
    end if;
    o.status := 'accepted';
    -- Who calls: whoever tapped the other (owner, D-145); otherwise the
    -- last to say yes. The caller needs the other's number — if only the
    -- caller's is shared, the other one calls instead.
    pref := coalesce(o.asked_by, me);
    callee := case when pref = o.user_a then o.user_b else o.user_a end;
    o.caller := case
      when not exists (select 1 from phone_numbers where user_id = callee)
           and exists (select 1 from phone_numbers where user_id = pref)
      then callee
      else pref end;
    o.accepted_at := now();
    o.not_before := now();
  end if;

  update match_offers
    set a_response = o.a_response, b_response = o.b_response, status = o.status,
        caller = o.caller, accepted_at = o.accepted_at, not_before = o.not_before,
        updated_at = now()
  where id = o.id;

  if o.status = 'accepted' then
    update match_offers set status = 'cancelled', updated_at = now()
    where status = 'pending' and id <> o.id
      and (o.user_a in (user_a, user_b) or o.user_b in (user_a, user_b));
  end if;

  return jsonb_build_object(
    'status', o.status,
    'i_call', o.status = 'accepted' and o.caller = me,
    'phone', case when o.status = 'accepted' and o.caller = me then call_phone_for(o, me) end);
end;
$$;
revoke all on function public.answer_offer_as(uuid, uuid, boolean) from public, anon, authenticated;

create or replace function public.answer_offer(p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return answer_offer_as(auth.uid(), p_offer, p_accept);
end;
$$;
revoke all on function public.answer_offer(uuid, boolean) from public, anon;
grant execute on function public.answer_offer(uuid, boolean) to authenticated;

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
    and a_response is null and b_response is null;
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
    -- Both said yes ahead of time for each other while driving: like quick
    -- connect (5 seconds, either can cancel, whoever starts calls), with
    -- no daily limit (owner, D-153).
    quick := (auto_yes_for(p_user, other.user_id) and auto_yes_for(other.user_id, p_user))
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
revoke all on function public.create_offers_for(uuid) from public, anon, authenticated;

-- Last: the version says 64 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 64 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261064000000_auto_yes_driving') on conflict do nothing;

notify pgrst, 'reload schema';
