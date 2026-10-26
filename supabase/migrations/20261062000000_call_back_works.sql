-- DriveBond — calling back works (D-148), and a tap replaces the app's own
-- question (D-147).
--
-- 1. "I missed a question" no longer sticks once I'm clearly here: saying
--    yes to anyone, or tapping a friend, clears it. Before, a friend I had
--    just tapped saw me grey and couldn't call me back.
-- 2. A "no" from me no longer blocks a friend I asked myself afterwards.
-- 3. Tapping a friend while the app's own question between us is still
--    unanswered: my direct ask replaces it (no "busy"), and I'm the caller.

create or replace function public.offer_here()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.quick then return new; end if;
  if new.a_response = 'accept'
     and (tg_op = 'INSERT' or old.a_response is distinct from 'accept') then
    update availability set missed_at = null
    where user_id = new.user_a and missed_at is not null;
  end if;
  if new.b_response = 'accept'
     and (tg_op = 'INSERT' or old.b_response is distinct from 'accept') then
    update availability set missed_at = null
    where user_id = new.user_b and missed_at is not null;
  end if;
  return new;
end;
$$;
revoke all on function public.offer_here() from public, anon, authenticated;
drop trigger if exists match_offers_here on public.match_offers;
create trigger match_offers_here
  after insert or update of a_response, b_response on public.match_offers
  for each row execute function public.offer_here();

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
               and o.created_at >= theirs.started_at
               -- …unless they asked us themselves after that "no" (D-148)
               and not exists (
                 select 1 from match_offers l
                 where l.user_a = lo and l.user_b = hi
                   and l.created_at > o.created_at
                   and (case when p_user = l.user_a then l.a_response else l.b_response end)
                       = 'accept')))) then
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
          me);
  return 'asked';
end;
$$;
revoke all on function public.ask_friend(uuid) from public, anon;
grant execute on function public.ask_friend(uuid) to authenticated;

-- Last: the version says 62 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 62 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261062000000_call_back_works') on conflict do nothing;

notify pgrst, 'reload schema';
