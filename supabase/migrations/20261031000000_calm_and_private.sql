-- DriveBond — calmer, more private, clearer about time (D-103…D-106).
--
-- Less pestering (D-104, D-106):
-- - Someone who didn't answer a question is no longer offered (and looks
--   "not free" to friends) until they say "still free" in the app.
-- - An automatic trip: 5 quiet minutes first, then at most ONE question
--   that wasn't a yes per trip. Two missed trips in a row → the app asks
--   (inside the app only) whether to keep automatic detection.
-- - The one who said "yes" doesn't wait 5 quiet minutes when the other
--   side didn't answer.
-- - Tapping a free friend asks them directly.
-- Privacy (D-103, D-106):
-- - "Free without my name": friends only see how many are free.
--   Whoever chooses it also sees only a number (fair, and a reason to
--   stay visible). The name shows in the question itself.
-- - "Hide when I'm in a call": then I look not-free while in a call.
-- - Someone who added me from their contacts while I don't have their
--   number doesn't see when I'm free until I keep them.
-- Time and comfort (D-106):
-- - Quiet hours: no automatic trip availability then.
-- - A question carries "you're both free until" and when they last talked.
-- - "Extend" my free time.
-- Crash reports: a short technical note, no personal data (owner only).

-- ------------------------------------------------------------ columns

alter table public.profiles
  add column if not exists anonymous boolean not null default false,
  add column if not exists hide_in_call boolean not null default false,
  add column if not exists quiet_from smallint check (quiet_from between 0 and 1439),
  add column if not exists quiet_to smallint check (quiet_to between 0 and 1439),
  add column if not exists time_zone text not null default 'Asia/Jerusalem',
  add column if not exists auto_missed smallint not null default 0;
-- (Not readable by friends: only the columns granted in D-094 are.)

alter table public.availability
  add column if not exists missed_at timestamptz,
  add column if not exists quiet_until timestamptz;
grant select (missed_at, quiet_until) on public.availability to authenticated;

alter table public.match_offers
  add column if not exists shared_until timestamptz,
  add column if not exists last_talk timestamptz,
  add column if not exists direct boolean not null default false;
grant select (shared_until, last_talk, direct) on public.match_offers to authenticated;

-- The one who must decide (kept private: only my_status() tells them).
alter table public.connections
  add column if not exists pending_for uuid references public.profiles(id) on delete cascade;

create table if not exists public.crash_reports (
  id bigserial primary key,
  user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  build text,
  kind text,
  message text,
  stack text
);
alter table public.crash_reports enable row level security;
create index if not exists crash_reports_user_idx on public.crash_reports (user_id, created_at);

-- ------------------------------------------------------------ helpers

create or replace function public.is_anonymous(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select anonymous from profiles where id = p_user), false);
$$;
revoke all on function public.is_anonymous(uuid) from public, anon;
grant execute on function public.is_anonymous(uuid) to authenticated;

create or replace function public.hides_call(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select hide_in_call from profiles where id = p_user), false);
$$;
revoke all on function public.hides_call(uuid) from public, anon;
grant execute on function public.hides_call(uuid) to authenticated;

-- p_owner hasn't yet kept p_viewer (who added them from contacts).
create or replace function public.awaits_approval(p_owner uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from connections c
    where c.user_a = least(p_owner, p_viewer) and c.user_b = greatest(p_owner, p_viewer)
      and c.pending_for = p_owner);
$$;
revoke all on function public.awaits_approval(uuid, uuid) from public, anon;
grant execute on function public.awaits_approval(uuid, uuid) to authenticated;

create or replace function public.pair_pending(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from connections c
    where c.user_a = least(p_a, p_b) and c.user_b = greatest(p_a, p_b)
      and c.pending_for is not null);
$$;
revoke all on function public.pair_pending(uuid, uuid) from public, anon, authenticated;

-- Inside my quiet hours (my own time zone)?
create or replace function public.in_quiet_hours(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((
    select case
      when p.quiet_from is null or p.quiet_to is null or p.quiet_from = p.quiet_to then false
      else (
        with t as (
          select (extract(hour from now() at time zone p.time_zone) * 60
                  + extract(minute from now() at time zone p.time_zone))::int as m)
        select case when p.quiet_from < p.quiet_to
                    then t.m >= p.quiet_from and t.m < p.quiet_to
                    else t.m >= p.quiet_from or t.m < p.quiet_to end
        from t)
    end
    from profiles p where p.id = p_user), false);
$$;
revoke all on function public.in_quiet_hours(uuid) from public, anon, authenticated;

-- Can p_viewer see p_owner's free time, apart from the "without my name"
-- rule? (Same rules as the availability policy.)
create or replace function public.sees_free_apart_from_name(p_viewer uuid, a availability)
returns boolean language sql stable security definer set search_path = public as $$
  select a.expires_at > now()
    and a.missed_at is null
    and are_connected(p_viewer, a.user_id)
    and not is_blocked_between(p_viewer, a.user_id)
    and in_audience(a.circle_id, p_viewer)
    and not hides_status(a.user_id)
    and not hides_status(p_viewer)
    and can_see(p_viewer, a.user_id, a.mode)
    and not awaits_approval(a.user_id, p_viewer)
    and not (hides_call(a.user_id)
             and coalesce(a.call_until > now() or a.phone_until > now(), false));
$$;
revoke all on function public.sees_free_apart_from_name(uuid, availability) from public, anon, authenticated;

drop policy if exists availability_select on public.availability;
create policy availability_select on public.availability for select to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now()
        and missed_at is null
        and public.are_connected(auth.uid(), user_id)
        and not public.is_blocked_between(auth.uid(), user_id)
        and public.in_audience(circle_id, auth.uid())
        and not public.hides_status(user_id)
        and not public.hides_status(auth.uid())
        and public.sees_availability(user_id)
        and not public.awaits_approval(user_id, auth.uid())
        and not (public.hides_call(user_id)
                 and coalesce(call_until > now() or phone_until > now(), false))
        and not public.is_anonymous(user_id)
        and not public.is_anonymous(auth.uid()))
  );

-- ------------------------------------------------------------ fewer questions

-- The 5 quiet minutes after a question that didn't become a call — only
-- for whoever didn't say yes to it.
create or replace function public.quiet_gap(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_offers o
    where p_user in (o.user_a, o.user_b)
      and o.status in ('declined', 'expired', 'cancelled')
      and o.updated_at > now() - interval '5 minutes'
      and (case when p_user = o.user_a then o.a_response else o.b_response end)
          is distinct from 'accept');
$$;
revoke all on function public.quiet_gap(uuid) from public, anon, authenticated;

-- Enough questions for this free time: 3, but on an automatic trip one
-- question I didn't say yes to is enough.
create or replace function public.asked_enough(p_user uuid, p_since timestamptz)
returns boolean language sql stable security definer set search_path = public as $$
  select case
    when exists (select 1 from availability where user_id = p_user and source = 'auto') then
      exists (
        select 1 from match_offers o
        where p_user in (o.user_a, o.user_b)
          and not o.quick
          and o.created_at >= p_since
          and o.status in ('declined', 'expired', 'cancelled')
          and (case when p_user = o.user_a then o.a_response else o.b_response end)
              is distinct from 'accept')
    else (
      select count(*) >= 3 from match_offers o
      where p_user in (o.user_a, o.user_b)
        and not o.quick
        and o.created_at >= p_since
        and o.status in ('declined', 'expired', 'cancelled'))
  end;
$$;
revoke all on function public.asked_enough(uuid, timestamptz) from public, anon, authenticated;

-- Can p_user get a question right now (their own side)?
create or replace function public.can_be_asked(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from availability a
    where a.user_id = p_user and a.expires_at > now()
      and a.missed_at is null
      and (a.quiet_until is null or a.quiet_until <= now())
      and not (a.source = 'auto' and in_quiet_hours(p_user)))
    and not has_open_offer(p_user)
    and not in_call(p_user)
    and not on_phone(p_user);
$$;
revoke all on function public.can_be_asked(uuid) from public, anon, authenticated;

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
      and not exists (
        select 1 from pair_snoozes z
        where z.until > now()
          and ((z.from_user = p_user and z.to_user = a.user_id)
               or (z.from_user = a.user_id and z.to_user = p_user)))
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
             or (o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes')
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

-- A question that ended without an answer from someone: they're not
-- offered (and look not free) until they say "still free". A missed
-- automatic trip is counted; any answer resets the count.
create or replace function public.offer_missed()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  u uuid;
begin
  if new.a_response is not null and old.a_response is null then
    update profiles set auto_missed = 0 where id = new.user_a and auto_missed > 0;
  end if;
  if new.b_response is not null and old.b_response is null then
    update profiles set auto_missed = 0 where id = new.user_b and auto_missed > 0;
  end if;
  if old.status = 'pending' and new.status in ('expired', 'declined')
     and not new.quick
     and new.updated_at >= new.created_at + interval '25 seconds' then
    foreach u in array array[
      case when new.a_response is null then new.user_a end,
      case when new.b_response is null then new.user_b end]
    loop
      continue when u is null;
      update profiles set auto_missed = least(auto_missed + 1, 100)
      where id = u
        and exists (select 1 from availability
                    where user_id = u and source = 'auto' and missed_at is null
                      and expires_at > now());
      update availability set missed_at = now()
      where user_id = u and missed_at is null and expires_at > now();
    end loop;
  end if;
  return new;
end;
$$;
drop trigger if exists match_offers_missed on public.match_offers;
create trigger match_offers_missed
  after update of status, a_response, b_response on public.match_offers
  for each row execute function public.offer_missed();

-- "I'm still free" (after a missed question).
create or replace function public.still_free()
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update availability set missed_at = null
  where user_id = auth.uid() and expires_at > now() and missed_at is not null;
  if not found then return false; end if;
  perform create_offers_for(auth.uid());
  return true;
end;
$$;
revoke all on function public.still_free() from public, anon;
grant execute on function public.still_free() to authenticated;

-- "Ready now" during the 5 quiet minutes of an automatic trip.
create or replace function public.ready_now()
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update availability set quiet_until = null
  where user_id = auth.uid() and expires_at > now() and quiet_until > now();
  if not found then return false; end if;
  perform create_offers_for(auth.uid());
  return true;
end;
$$;
revoke all on function public.ready_now() from public, anon;
grant execute on function public.ready_now() to authenticated;

-- "Keep automatic detection" after missed trips.
create or replace function public.keep_auto()
returns void language sql security definer set search_path = public as $$
  update profiles set auto_missed = 0 where id = auth.uid();
$$;
revoke all on function public.keep_auto() from public, anon;
grant execute on function public.keep_auto() to authenticated;

-- Automatic trip: not in quiet hours; a new trip starts with 5 quiet
-- minutes and a clean slate.
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
        missed_at = case when same_trip then availability.missed_at end,
        quiet_until = case when same_trip then availability.quiet_until
                           else now() + interval '5 minutes' end;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return 'available';
end;
$$;
grant execute on function public.auto_start(text, integer) to anon, authenticated;

-- Manual "I have time" (app, widget, routine): a fresh start.
create or replace function public.set_availability(p_mode text, p_minutes integer, p_circle uuid default null)
returns availability language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  result availability;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_minutes is null or p_minutes < 1 or p_minutes > 180 then
    raise exception 'invalid_minutes';
  end if;
  if p_circle is not null and not exists (
    select 1 from circles where id = p_circle and owner = me) then
    raise exception 'invalid_circle';
  end if;
  insert into availability (user_id, mode, started_at, expires_at, source, circle_id)
  values (me, p_mode, now(), now() + make_interval(mins => p_minutes), 'manual', p_circle)
  on conflict (user_id) do update
    set mode = excluded.mode,
        started_at = excluded.started_at,
        expires_at = excluded.expires_at,
        source = 'manual',
        circle_id = excluded.circle_id,
        missed_at = null,
        quiet_until = null
  returning * into result;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return result;
end;
$$;

create or replace function public.device_start(p_token text, p_mode text default 'free',
                                               p_minutes integer default 30, p_circle uuid default null)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  mins integer := least(greatest(coalesce(p_minutes, 30), 1), 180);
  until timestamptz;
  circle uuid := null;
begin
  if me is null then return null; end if;
  if p_mode not in ('driving', 'walking', 'breakTime', 'free') then
    p_mode := 'free';
  end if;
  if p_circle is not null then
    if not exists (select 1 from circles where id = p_circle and owner = me) then
      return null;
    end if;
    circle := p_circle;
  end if;
  until := now() + make_interval(mins => mins);
  insert into availability (user_id, mode, started_at, expires_at, source, circle_id)
  values (me, p_mode, now(), until, 'manual', circle)
  on conflict (user_id) do update
    set mode = excluded.mode, started_at = now(), expires_at = until,
        source = 'manual', circle_id = circle, missed_at = null, quiet_until = null;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return until;
end;
$$;

-- "Extend": more minutes on my manual free time (3 hours at most).
create or replace function public.extend_availability(p_minutes integer)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  until timestamptz;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_minutes is null or p_minutes < 1 or p_minutes > 180 then
    raise exception 'invalid_minutes';
  end if;
  update availability
  set expires_at = least(expires_at + make_interval(mins => p_minutes),
                         started_at + interval '3 hours')
  where user_id = auth.uid() and expires_at > now() and source = 'manual'
  returning expires_at into until;
  return until;
end;
$$;
revoke all on function public.extend_availability(integer) from public, anon;
grant execute on function public.extend_availability(integer) to authenticated;

-- Tap a free friend: ask them now (I say yes at once). Their own
-- protections all stay (busy, missed, quiet minutes, said no already).
create or replace function public.ask_friend(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  mine availability;
  theirs availability;
  lo uuid;
  hi uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(727274);
  select * into mine from availability where user_id = me and expires_at > now();
  if not found then return 'me_not_free'; end if;
  if (select count(*) from match_offers o
      where o.direct and me in (o.user_a, o.user_b)
        and o.created_at > now() - interval '1 hour') >= 10 then
    return 'rate_limited';
  end if;
  select * into theirs from availability where user_id = p_user;
  if not found or p_user = me
     or not sees_free_apart_from_name(me, theirs)
     or is_anonymous(p_user) or is_anonymous(me)
     or pair_pending(me, p_user)
     or rating_of(p_user, me) = 0
     or exists (select 1 from pair_snoozes z
                where z.until > now() and z.from_user = p_user and z.to_user = me) then
    return 'not_free';
  end if;
  if not exists (select 1 from phone_numbers n where n.user_id in (me, p_user)) then
    return 'no_number';
  end if;
  if not can_be_asked(p_user) or asked_enough(p_user, theirs.started_at) then
    return 'busy';
  end if;
  lo := least(me, p_user);
  hi := greatest(me, p_user);
  if exists (
    select 1 from match_offers o
    where o.user_a = lo and o.user_b = hi
      and ((o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes')
           -- they already said no to us this time
           or (o.status = 'declined'
               and (case when p_user = o.user_a then o.a_response else o.b_response end)
                   = 'decline'
               and o.created_at >= theirs.started_at))) then
    return 'not_now';
  end if;
  -- My own open question (if any) gives way to this one.
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and me in (user_a, user_b);
  insert into match_offers (user_a, user_b, expires_at, shared_until, last_talk, direct,
                            a_response, b_response)
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
          case when me = hi then 'accept' end);
  return 'asked';
end;
$$;
revoke all on function public.ask_friend(uuid) from public, anon;
grant execute on function public.ask_friend(uuid) to authenticated;

-- Withdrawing my "yes" (I stopped waiting) keeps it a yes: the question
-- ends, but I'm not the one who said no (no quiet minutes for me, D-104).
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
      update match_offers set status = 'expired', updated_at = now() where id = o.id;
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

-- ------------------------------------------------------------ privacy

create or replace function public.set_settings(
  p_anonymous boolean default null,
  p_hide_in_call boolean default null,
  p_quiet_from integer default null,
  p_quiet_to integer default null,
  p_clear_quiet boolean default false,
  p_time_zone text default null)
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
    time_zone = coalesce(p_time_zone, time_zone)
  where id = auth.uid();
end;
$$;
revoke all on function public.set_settings(boolean, boolean, integer, integer, boolean, text) from public, anon;
grant execute on function public.set_settings(boolean, boolean, integer, integer, boolean, text) to authenticated;

-- Everything about me the app needs that friends must not read.
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
    'auto_missed', p.auto_missed,
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

-- Keep a friend who added me (they now see when I'm free, as usual).
create or replace function public.approve_friend(p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update connections set pending_for = null
  where user_a = least(auth.uid(), p_user) and user_b = greatest(auth.uid(), p_user)
    and pending_for = auth.uid();
  if not found then return false; end if;
  perform create_offers_for(auth.uid());
  return true;
end;
$$;
revoke all on function public.approve_friend(uuid) from public, anon;
grant execute on function public.approve_friend(uuid) to authenticated;

-- Adding from my contacts: if they don't have my number saved (as far as
-- the server knows), they decide before I see when they're free.
create or replace function public.add_contacts(p_users uuid[])
returns table (display_name text) language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  other record;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  for other in
    select pn.user_id, pr.display_name
    from phone_numbers pn
    join profiles pr on pr.id = pn.user_id
    where pn.user_id = any (p_users)
      and pn.user_id <> me
      and pn.phone_hash in (select hash from contact_hashes where owner = me)
      and not is_blocked_between(me, pn.user_id)
      and not are_connected(me, pn.user_id)
      and not was_removed(me, pn.user_id)
  loop
    insert into connections (user_a, user_b, pending_for)
    values (least(me, other.user_id), greatest(me, other.user_id),
            case when exists (
              select 1 from phone_numbers mine
              join contact_hashes h on h.hash = mine.phone_hash
              where mine.user_id = me and h.owner = other.user_id)
            then null else other.user_id end)
    on conflict do nothing;
    display_name := other.display_name;
    return next;
  end loop;
  perform create_offers_for(me);
end;
$$;

-- Contacts search, as before (D-102) — and anyone found who added me and
-- waits for my decision is kept: I have their number, I know them.
create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  delete from contact_hashes where owner = me;
  if p_hashes is null or array_length(p_hashes, 1) is null then return; end if;
  if array_length(p_hashes, 1) > 5000 then raise exception 'too_many_contacts'; end if;
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  update connections c set pending_for = null
  where c.pending_for = me
    and exists (
      select 1 from phone_numbers pn
      join contact_hashes h on h.hash = pn.phone_hash and h.owner = me
      where pn.user_id = case when c.user_a = me then c.user_b else c.user_a end);

  return query
    select x.user_id, x.display_name, x.phone_hash, x.is_friend
    from (
      select distinct on (pn.phone_hash)
             pn.user_id, pr.display_name, pn.phone_hash,
             are_connected(me, pn.user_id) as is_friend
      from phone_numbers pn
      join profiles pr on pr.id = pn.user_id
      where pn.user_id <> me
        and pn.phone_hash in (select c.hash from contact_hashes c where c.owner = me)
        and not is_blocked_between(me, pn.user_id)
      order by pn.phone_hash,
               replaced_account(pn.user_id) asc,
               are_connected(me, pn.user_id) desc,
               pr.last_seen_at desc
    ) x
    where x.is_friend or not was_removed(me, x.user_id)
    order by x.display_name;
end;
$$;

-- ------------------------------------------------------------ crash notes

create or replace function public.report_crash(p_build text, p_kind text, p_message text, p_stack text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from crash_reports
      where user_id = auth.uid() and created_at > now() - interval '1 day') >= 20 then
    return;
  end if;
  insert into crash_reports (user_id, build, kind, message, stack)
  values (auth.uid(), left(p_build, 40), left(p_kind, 40), left(p_message, 500),
          left(p_stack, 4000));
end;
$$;
revoke all on function public.report_crash(text, text, text, text) from public, anon;
grant execute on function public.report_crash(text, text, text, text) to authenticated;

create or replace function public.owner_crashes()
returns table (created_at timestamptz, build text, kind text, message text, stack text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_owner() then raise exception 'not_owner'; end if;
  return query
    select r.created_at, r.build, r.kind, r.message, r.stack
    from crash_reports r order by r.created_at desc limit 50;
end;
$$;
revoke all on function public.owner_crashes() from public, anon;
grant execute on function public.owner_crashes() to authenticated;

-- The owner's numbers (D-102) + crashes.
create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not is_owner() then raise exception 'not_owner'; end if;
  return jsonb_build_object(
    'users', (select count(distinct coalesce(n.phone_hash, p.id::text))
              from profiles p left join phone_numbers n on n.user_id = p.id),
    'new_users', (select count(distinct coalesce(n.phone_hash, p.id::text))
                  from profiles p left join phone_numbers n on n.user_id = p.id
                  where p.created_at >= since
                    and not exists (select 1 from phone_numbers o join profiles op on op.id = o.user_id
                                    where o.phone_hash = n.phone_hash and o.user_id <> p.id
                                      and op.created_at < since)),
    'active_users', (select count(distinct coalesce(n.phone_hash, p.id::text))
                     from profiles p left join phone_numbers n on n.user_id = p.id
                     where p.last_seen_at >= since),
    'friendships', (select count(*) from connections c
                    where not replaced_account(c.user_a) and not replaced_account(c.user_b)),
    'free_times', (select count(*) from app_events where name = 'availability_started' and created_at >= since),
    'offers', (select count(*) from match_offers where created_at >= since and not quick),
    'quick', (select count(*) from match_offers where created_at >= since and quick),
    'both_yes', (select count(*) from match_offers where created_at >= since and status = 'accepted'),
    'talked', (select count(*) from match_offers where created_at >= since and talked),
    'declined', (select count(*) from match_offers where created_at >= since and status = 'declined'),
    'later', (select count(*) from match_offers where created_at >= since and later_from is not null),
    'no_answer', (select count(*) from match_offers where created_at >= since and status = 'expired'),
    'reports', (select count(*) from reports where created_at >= since),
    'feedback', (select count(*) from feedback_notes where created_at >= since),
    'crashes', (select count(*) from crash_reports where created_at >= since),
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  );
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

-- Last: the version says 31 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 31 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261031000000_calm_and_private') on conflict do nothing;
