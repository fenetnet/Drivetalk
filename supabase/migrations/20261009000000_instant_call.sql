-- DriveTalk — the call starts at once (D-060).
--
-- * Normal match: the side that says the second "yes" is the caller and gets
--   the number in the same reply (answer_offer) → it dials right away.
-- * Quick connect: a real server countdown. The 5 seconds to cancel start
--   only after BOTH phones have seen it (seen_call / auto_offers); the
--   number is given only after that (start_call), and either side can cancel.
-- * One offer at a time per person, and never two calls at once.
-- * Quick connect at most once per availability window (and once a day per pair).

alter table public.match_offers add column if not exists caller uuid;
alter table public.match_offers add column if not exists accepted_at timestamptz;
alter table public.match_offers add column if not exists not_before timestamptz;
alter table public.match_offers add column if not exists seen_a timestamptz;
alter table public.match_offers add column if not exists seen_b timestamptz;
alter table public.match_offers add column if not exists ended_a boolean not null default false;
alter table public.match_offers add column if not exists ended_b boolean not null default false;

-- Calls agreed before this file: treat them as already started.
update public.match_offers
set accepted_at = coalesce(accepted_at, updated_at), not_before = coalesce(not_before, updated_at)
where status = 'accepted' and accepted_at is null;

-- Am I in a call right now (agreed, not finished, not too old)?
create or replace function public.in_call(p_user uuid, p_except uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_offers o
    where o.status = 'accepted'
      and o.id is distinct from p_except
      and o.accepted_at > now() - interval '20 minutes'
      and ((o.user_a = p_user and not o.ended_a) or (o.user_b = p_user and not o.ended_b))
  );
$$;
revoke all on function public.in_call(uuid, uuid) from public, anon, authenticated;

-- Has this user got an open question ("talk?") waiting?
create or replace function public.has_open_offer(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_offers o
    where o.status = 'pending' and o.expires_at > now() and p_user in (o.user_a, o.user_b)
  );
$$;
revoke all on function public.has_open_offer(uuid) from public, anon, authenticated;

-- Find ONE friend for this user (the best one), if both are free.
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
  select * into mine from availability where user_id = p_user and expires_at > now();
  if not found then return 0; end if;
  if has_open_offer(p_user) or in_call(p_user) then return 0; end if;

  for other in
    select a.user_id, a.expires_at, a.circle_id, a.started_at,
           (select max(o.accepted_at) from match_offers o
            where o.status = 'accepted'
              and o.user_a = least(p_user, a.user_id)
              and o.user_b = greatest(p_user, a.user_id)) as last_talk
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and not is_blocked_between(p_user, a.user_id)
    -- Quietly: quick-connect friends first, then whoever I talked with
    -- least recently (never = first).
    order by (is_quick(p_user, a.user_id) and is_quick(a.user_id, p_user)) desc,
             last_talk asc nulls first,
             random()
  loop
    if not in_audience(mine.circle_id, other.user_id)
       or not in_audience(other.circle_id, p_user)
       or has_open_offer(other.user_id)
       or in_call(other.user_id) then
      continue;
    end if;
    lo := least(p_user, other.user_id);
    hi := greatest(p_user, other.user_id);
    if exists (
      select 1 from match_offers o
      where o.user_a = lo and o.user_b = hi
        and ((o.status = 'declined' and o.updated_at > now() - interval '2 minutes')
             -- after a call: not the same pair again for 30 minutes
             or (o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes'))
    ) then
      continue;
    end if;
    quick := is_quick(p_user, other.user_id) and is_quick(other.user_id, p_user)
      -- once a day per pair
      and not exists (
        select 1 from match_offers o
        where o.user_a = lo and o.user_b = hi and o.quick
          and o.created_at > now() - interval '1 day')
      -- once per availability window, for each of them
      and not exists (
        select 1 from match_offers o
        where o.quick and p_user in (o.user_a, o.user_b) and o.created_at >= mine.started_at)
      and not exists (
        select 1 from match_offers o
        where o.quick and other.user_id in (o.user_a, o.user_b) and o.created_at >= other.started_at);
    if quick then
      -- Agreed in advance, but nobody may dial before both had 5 seconds to
      -- cancel (not_before is set when both phones have seen it).
      insert into match_offers (user_a, user_b, expires_at, status, a_response, b_response,
                                quick, accepted_at)
      values (lo, hi, least(mine.expires_at, other.expires_at), 'accepted', 'accept', 'accept',
              true, now());
    else
      insert into match_offers (user_a, user_b, expires_at)
      values (lo, hi, least(mine.expires_at, other.expires_at))
      on conflict do nothing;
    end if;
    return 1;
  end loop;
  return 0;
end;
$$;
revoke all on function public.create_offers_for(uuid) from public, anon, authenticated;

-- The phone number the caller dials (only the caller, only once allowed).
create or replace function public.call_phone_for(o match_offers, p_me uuid)
returns text language sql stable security definer set search_path = public as $$
  select phone from phone_numbers
  where user_id = case when p_me = o.user_a then o.user_b else o.user_a end
    and not is_blocked_between(o.user_a, o.user_b);
$$;
revoke all on function public.call_phone_for(match_offers, uuid) from public, anon, authenticated;

-- Answer "talk?". The second "yes" makes me the caller: the reply already
-- has the number, so the phone can dial at once.
-- Returns {status, i_call, phone}.
create or replace function public.answer_offer(p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  answer text := case when p_accept then 'accept' else 'decline' end;
begin
  if me is null then raise exception 'not_authenticated'; end if;
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
                    then call_phone_for(o, me) end);
  end if;
  if o.expires_at <= now()
     or not exists (select 1 from availability where user_id = o.user_a and expires_at > now())
     or not exists (select 1 from availability where user_id = o.user_b and expires_at > now()) then
    update match_offers set status = 'expired', updated_at = now() where id = o.id;
    return jsonb_build_object('status', 'expired');
  end if;

  if me = o.user_a then o.a_response := answer; else o.b_response := answer; end if;

  if answer = 'decline' then
    o.status := 'declined';
  elsif o.a_response = 'accept' and o.b_response = 'accept' then
    -- Never two calls at once.
    if in_call(o.user_a, o.id) or in_call(o.user_b, o.id) then
      update match_offers set status = 'expired', updated_at = now() where id = o.id;
      return jsonb_build_object('status', 'expired');
    end if;
    o.status := 'accepted';
    -- I dial (I'm looking at the phone right now) — unless only I shared a
    -- number: then they dial me.
    o.caller := case
      when not exists (select 1 from phone_numbers
                       where user_id = case when me = o.user_a then o.user_b else o.user_a end)
           and exists (select 1 from phone_numbers where user_id = me)
      then case when me = o.user_a then o.user_b else o.user_a end
      else me end;
    o.accepted_at := now();
    o.not_before := now();
  end if;

  update match_offers
    set a_response = o.a_response, b_response = o.b_response, status = o.status,
        caller = o.caller, accepted_at = o.accepted_at, not_before = o.not_before,
        updated_at = now()
  where id = o.id;

  if o.status = 'accepted' then
    -- Anything else that was open for either of them is no longer relevant.
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
revoke all on function public.answer_offer(uuid, boolean) from public, anon;
grant execute on function public.answer_offer(uuid, boolean) to authenticated;

-- The older app still calls respond_offer: same rules.
create or replace function public.respond_offer(p_offer uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = public as $$
begin
  return answer_offer(p_offer, p_accept) ->> 'status';
end;
$$;

-- Quick connect: "my phone shows it now" — starts the 5 seconds once both saw it.
create or replace function public.mark_seen(p_offer uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update match_offers
  set seen_a = case when p_user = user_a then coalesce(seen_a, now()) else seen_a end,
      seen_b = case when p_user = user_b then coalesce(seen_b, now()) else seen_b end,
      updated_at = now()
  where id = p_offer and quick and status = 'accepted' and not_before is null
    and p_user in (user_a, user_b);
  update match_offers
  set not_before = greatest(seen_a, seen_b) + interval '5 seconds', updated_at = now()
  where id = p_offer and quick and status = 'accepted' and not_before is null
    and seen_a is not null and seen_b is not null;
end;
$$;
revoke all on function public.mark_seen(uuid, uuid) from public, anon, authenticated;

create or replace function public.seen_call(p_offer uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  perform mark_seen(p_offer, auth.uid());
end;
$$;
revoke all on function public.seen_call(uuid) from public, anon;
grant execute on function public.seen_call(uuid) to authenticated;

-- Cancel during the 5 seconds (either side). Reaches the other side via
-- Realtime / the background check. True if it was cancelled.
create or replace function public.cancel_call_for(p_offer uuid, p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  update match_offers set status = 'cancelled', updated_at = now()
  where id = p_offer and p_user in (user_a, user_b) and status = 'accepted'
    and quick and (not_before is null or now() < not_before);
  get diagnostics n = row_count;
  return n > 0;
end;
$$;
revoke all on function public.cancel_call_for(uuid, uuid) from public, anon, authenticated;

create or replace function public.cancel_call(p_offer uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return cancel_call_for(p_offer, auth.uid());
end;
$$;
revoke all on function public.cancel_call(uuid) from public, anon;
grant execute on function public.cancel_call(uuid) to authenticated;

create or replace function public.device_cancel_call(p_token text, p_offer uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return false; end if;
  return cancel_call_for(p_offer, me);
end;
$$;
grant execute on function public.device_cancel_call(text, uuid) to anon, authenticated;

-- After the 5 seconds: the first phone to ask becomes the caller and gets
-- the number; the other learns that they will be called.
-- Returns {state: 'ready'|'wait'|'cancelled'|'gone', i_call, phone, wait_ms}.
create or replace function public.start_call(p_offer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then
    return jsonb_build_object('state', 'gone');
  end if;
  if o.status = 'cancelled' then return jsonb_build_object('state', 'cancelled'); end if;
  if o.status <> 'accepted' or o.accepted_at < now() - interval '30 minutes'
     or is_blocked_between(o.user_a, o.user_b) then
    return jsonb_build_object('state', 'gone');
  end if;
  if o.not_before is null then
    perform mark_seen(o.id, me);
    select * into o from match_offers where id = p_offer;
  end if;
  if o.not_before is null or now() < o.not_before then
    return jsonb_build_object('state', 'wait', 'wait_ms',
      case when o.not_before is null then 1000
           else greatest(100, ceil(extract(epoch from (o.not_before - now())) * 1000)::int) end);
  end if;
  if o.caller is null then
    update match_offers set caller = me, updated_at = now() where id = o.id;
    o.caller := me;
  end if;
  return jsonb_build_object(
    'state', 'ready',
    'i_call', o.caller = me,
    'phone', case when o.caller = me then call_phone_for(o, me) end);
end;
$$;
revoke all on function public.start_call(uuid) from public, anon;
grant execute on function public.start_call(uuid) to authenticated;

-- The call is over for me (after the feedback question, or skipped).
create or replace function public.end_call(p_offer uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  update match_offers
  set ended_a = ended_a or me = user_a, ended_b = ended_b or me = user_b, updated_at = now()
  where id = p_offer and me in (user_a, user_b);
end;
$$;
revoke all on function public.end_call(uuid) from public, anon;
grant execute on function public.end_call(uuid) to authenticated;

-- The older app's call_details: the number only for the caller, and never
-- during the quick-connect countdown.
create or replace function public.call_details(p_offer uuid)
returns table (other_phone text, i_share boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into o from match_offers where id = p_offer;
  if not found or me not in (o.user_a, o.user_b) or o.status <> 'accepted'
     or o.accepted_at < now() - interval '30 minutes'
     or o.not_before is null or now() < o.not_before
     or (o.caller is not null and o.caller <> me) then
    return query select null::text, exists (select 1 from phone_numbers where user_id = me);
    return;
  end if;
  return query select
    call_phone_for(o, me),
    exists (select 1 from phone_numbers where user_id = me);
end;
$$;

-- Background check (device token): also marks quick connects as seen, so
-- their countdown starts; reports not_before for the notification.
drop function if exists public.auto_offers(text);
create or replace function public.auto_offers(p_token text)
returns table (offer_id uuid, other_name text, kind text, not_before timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  q record;
begin
  if me is null then return; end if;
  perform create_offers_for(me);
  for q in
    select o.id from match_offers o
    where me in (o.user_a, o.user_b) and o.quick and o.status = 'accepted'
      and o.not_before is null and o.accepted_at > now() - interval '3 minutes'
  loop
    perform mark_seen(q.id, me);
  end loop;
  return query
    select o.id, p.display_name,
           case when o.quick then 'quick' else 'ask' end,
           o.not_before
    from match_offers o
    join profiles p on p.id = case when o.user_a = me then o.user_b else o.user_a end
    where me in (o.user_a, o.user_b)
      and not is_blocked_between(o.user_a, o.user_b)
      and (
        (o.status = 'pending' and o.expires_at > now()
         and (case when o.user_a = me then o.a_response else o.b_response end) is null)
        or (o.quick and o.status = 'accepted' and o.accepted_at > now() - interval '3 minutes'
            and o.caller is null)
      )
    order by o.created_at;
end;
$$;
grant execute on function public.auto_offers(text) to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261009000000_instant_call') on conflict do nothing;
