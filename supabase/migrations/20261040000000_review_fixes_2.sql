-- DriveBond — fixes from the full review (D-115).
--
-- 1. A phone's number fingerprint (hash) always matches its number: it is
--    recomputed on every change, so nobody can pose as someone else in
--    contact search.
-- 2. A late "Talk" on a notification for a call that was already agreed
--    no longer switches who dials (both phones calling each other).
-- 3. Tapping a friend works only when that friend can also see that I'm
--    free (D-107: who doesn't see me isn't listed or asked).
-- 4. Removing a friend: open questions between the two end, an old unused
--    invitation link no longer brings them back (D-090), and answering /
--    starting a call needs the two to still be friends.
-- 5. Quick connect: nobody started it within 2 minutes of its countdown →
--    it never dials later (D-026), and it stops counting as "in a call".
--    A cancelled quick connect isn't counted as a talk.
-- 6. An automatic trip is never limited to the group of an earlier
--    manual window.
-- 7. Friends tapping me don't use up my own "ask" limit.
-- 8. Both said yes while one was in another call: their answers are kept
--    (nobody is marked "didn't answer").

-- ------------------------------------------------------- 1. number hash

drop trigger if exists phone_numbers_hash on public.phone_numbers;
create trigger phone_numbers_hash before insert or update on public.phone_numbers
  for each row execute function public.phone_numbers_hash();
-- Any row changed directly before this: recompute.
update public.phone_numbers
set phone = phone
where phone_hash is distinct from encode(extensions.digest(public.e164(phone), 'sha256'), 'hex');

-- ------------------------------------------------- 2. a late "Talk" tap

create or replace function public.device_answer(p_token text, p_offer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  r jsonb;
  o match_offers;
  other uuid;
  before text;
begin
  if me is null then return jsonb_build_object('status', 'bad_token'); end if;
  select status into before from match_offers where id = p_offer;
  -- Already agreed (e.g. in the app): nothing to answer, nothing to change.
  if before = 'accepted' then
    return jsonb_build_object('status', 'handled');
  end if;
  -- The very same answer as in the app, as this user.
  perform set_config('request.jwt.claim.sub', me::text, true);
  r := answer_offer(p_offer, true);
  if r ->> 'status' = 'accepted' then
    select * into o from match_offers where id = p_offer;
    other := case when me = o.user_a then o.user_b else o.user_a end;
    -- I can't dial from here: the other side calls me, if they can.
    if o.caller = me and exists (select 1 from phone_numbers where user_id = me) then
      update match_offers set caller = other, updated_at = now() where id = o.id;
      return jsonb_build_object('status', 'accepted', 'i_call', false);
    end if;
    return jsonb_build_object('status', 'accepted', 'i_call', o.caller = me);
  end if;
  return jsonb_build_object('status', r ->> 'status');
end;
$$;
revoke all on function public.device_answer(text, uuid) from public;
grant execute on function public.device_answer(text, uuid) to anon, authenticated;

-- ------------------------------------------- 3. tapping a friend: both ways

create or replace function public.ask_check(p_me uuid, p_user uuid, p_me_free boolean)
returns text language plpgsql stable security definer set search_path = public as $$
declare
  theirs availability;
  mine availability;
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
  -- And they must be allowed to see that I'm free (my groups, my modes).
  select * into mine from availability where user_id = p_me and expires_at > now();
  if found and (not in_audience(mine.circle_id, p_user)
                or not can_see(p_user, p_me, mine.mode)) then
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
      and ((o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes'
            and not (o.ended_a and o.ended_b))
           -- they already said no to us this time
           or (o.status = 'declined'
               and (case when p_user = o.user_a then o.a_response else o.b_response end)
                   = 'decline'
               and o.created_at >= theirs.started_at))) then
    return 'not_now';
  end if;
  return 'ok';
end;
$$;
revoke all on function public.ask_check(uuid, uuid, boolean) from public, anon, authenticated;

-- ------------------------------------------------------ 4. removing a friend

create or replace function public.remember_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    delete from circle_members m using circles c
    where m.circle_id = c.id
      and ((c.owner = old.user_a and m.member = old.user_b)
           or (c.owner = old.user_b and m.member = old.user_a));
    -- Open questions between the two end now (and a quick connect that
    -- hasn't started).
    update match_offers set status = 'cancelled', updated_at = now()
    where user_a = least(old.user_a, old.user_b) and user_b = greatest(old.user_a, old.user_b)
      and (status = 'pending' or (status = 'accepted' and quick and caller is null));
    if exists (select 1 from profiles where id = old.user_a)
       and exists (select 1 from profiles where id = old.user_b) then
      insert into removed_pairs (user_a, user_b, removed_by)
      values (old.user_a, old.user_b, auth.uid())
      on conflict (user_a, user_b) do update set removed_by = excluded.removed_by,
                                                 created_at = now();
    end if;
    return old;
  end if;
  delete from removed_pairs where user_a = new.user_a and user_b = new.user_b;
  return new;
end;
$$;
revoke all on function public.remember_removed() from public, anon, authenticated;

create or replace function public.accept_invitation(p_token text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  inv invitations;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from profiles where id = me) then
    raise exception 'no_profile';
  end if;
  select * into inv from invitations where token = p_token for update;
  if not found then return 'not_found'; end if;
  if inv.inviter_id = me then return 'own'; end if;
  if are_connected(me, inv.inviter_id) then return 'already_connected'; end if;
  if inv.accepted_by is not null then return 'used'; end if;
  if inv.expires_at <= now() then return 'expired'; end if;
  if is_blocked_between(me, inv.inviter_id) then return 'not_found'; end if;
  -- They removed me after this link was made: the old link doesn't bring
  -- me back (a new invitation from them does).
  if exists (
    select 1 from removed_pairs r
    where r.user_a = least(me, inv.inviter_id) and r.user_b = greatest(me, inv.inviter_id)
      and r.removed_by = inv.inviter_id and r.created_at > inv.created_at) then
    return 'expired';
  end if;

  insert into connections (user_a, user_b, via_invitation)
  values (least(me, inv.inviter_id), greatest(me, inv.inviter_id), inv.id)
  on conflict do nothing;
  update invitations set accepted_by = me, accepted_at = now() where id = inv.id;
  -- If both happen to be available right now, offer a call.
  perform create_offers_for(me);
  return 'accepted';
end;
$$;
revoke all on function public.accept_invitation(text) from public, anon;
grant execute on function public.accept_invitation(text) to authenticated;

create or replace function public.answer_offer(p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  answer text := case when p_accept then 'accept' else 'decline' end;
  withdrawn boolean;
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

-- ------------------------------------------------------ 5. quick connect

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
  -- The other side already gave up / ended: never start it any more.
  if (me = o.user_a and o.ended_b) or (me = o.user_b and o.ended_a) then
    return jsonb_build_object('state', 'gone');
  end if;
  if o.status <> 'accepted' or o.accepted_at < now() - interval '30 minutes'
     or is_blocked_between(o.user_a, o.user_b)
     or not are_connected(o.user_a, o.user_b) then
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
  -- Nobody started it while its countdown was fresh: it never dials out of
  -- the blue minutes later (D-026). It just ends.
  if o.quick and o.caller is null and o.not_before < now() - interval '2 minutes' then
    update match_offers set status = 'cancelled', updated_at = now() where id = o.id;
    return jsonb_build_object('state', 'gone');
  end if;
  if o.caller is null then
    -- Like answer_offer: the caller needs the other's number — if only I
    -- shared one, they call me.
    o.caller := case
      when not exists (select 1 from phone_numbers
                       where user_id = case when me = o.user_a then o.user_b else o.user_a end)
           and exists (select 1 from phone_numbers where user_id = me)
      then case when me = o.user_a then o.user_b else o.user_a end
      else me end;
    update match_offers set caller = o.caller, updated_at = now() where id = o.id;
  end if;
  return jsonb_build_object(
    'state', 'ready',
    'i_call', o.caller = me,
    'phone', case when o.caller = me then call_phone_for(o, me) end);
end;
$$;
revoke all on function public.start_call(uuid) from public, anon;
grant execute on function public.start_call(uuid) to authenticated;

-- A quick connect nobody started (2 minutes after its countdown) is no
-- longer "in a call".
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
      and ((o.user_a = p_user and not o.ended_a) or (o.user_b = p_user and not o.ended_b))
  );
$$;
revoke all on function public.in_call(uuid, uuid) from public, anon, authenticated;

-- A cancelled quick connect never happened: not a talk (stats, "last
-- talked", the nightly cleanup's keep rule).
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
    if new.ended_a and not old.ended_a then
      update availability set call_until = null where user_id = new.user_a;
    end if;
    if new.ended_b and not old.ended_b then
      update availability set call_until = null where user_id = new.user_b;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.mark_app_call() from public, anon, authenticated;
-- Earlier cancelled quick connects that were counted as talks.
update public.match_offers set talked = null where status <> 'accepted' and talked;

-- ------------------------------------------------------ 6. automatic trips

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
  insert into availability (user_id, mode, started_at, expires_at, source, quiet_until)
  values (me, 'driving', now(), now() + make_interval(mins => mins), 'auto',
          now() + interval '5 minutes')
  on conflict (user_id) do update
    set mode = 'driving',
        started_at = case when same_trip then availability.started_at else now() end,
        expires_at = least(
          now() + make_interval(mins => mins),
          case when same_trip then availability.started_at else now() end + interval '3 hours'),
        source = 'auto',
        -- A trip is for everyone (never the group of an earlier window).
        circle_id = null,
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

-- ------------------------------------------------ 7. my own "ask" limit

alter table public.match_offers add column if not exists asked_by uuid;

create or replace function public.ask_friend(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  mine availability;
  theirs availability;
  lo uuid;
  hi uuid;
  why text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(727274);
  -- Only the friends I tapped count (not friends tapping me).
  if (select count(*) from match_offers o
      where o.direct and o.asked_by = me
        and o.created_at > now() - interval '1 hour') >= 10 then
    return 'rate_limited';
  end if;
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
          me);
  return 'asked';
end;
$$;
revoke all on function public.ask_friend(uuid) from public, anon;
grant execute on function public.ask_friend(uuid) to authenticated;

-- Last: the version says 40 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 40 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261040000000_review_fixes_2') on conflict do nothing;
