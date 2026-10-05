-- DriveTalk — after the call (D-062).
-- * "We talked" is separate from "both said yes": the week summary and the
--   "longest without talking" order count only real talks.
-- * After a call: "it was good" / "not again soon" (7 days, never told) /
--   "we didn't actually talk". One answer per person per call.
-- * Routines can be for one circle (device_start p_circle).

alter table public.match_offers add column if not exists talked boolean;

create table if not exists public.pair_snoozes (
  from_user uuid not null references public.profiles (id) on delete cascade,
  to_user uuid not null references public.profiles (id) on delete cascade,
  until timestamptz not null,
  primary key (from_user, to_user)
);
alter table public.pair_snoozes enable row level security;
revoke all on public.pair_snoozes from anon, authenticated;

-- p_result: 'good' | 'not_soon' | 'no_talk'.
create or replace function public.call_feedback(p_offer uuid, p_result text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  other uuid;
  did_talk boolean := p_result in ('good', 'not_soon');
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_result not in ('good', 'not_soon', 'no_talk') then raise exception 'invalid_result'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) or o.status <> 'accepted' then
    raise exception 'not_found';
  end if;
  other := case when me = o.user_a then o.user_b else o.user_a end;
  -- One answer per person per call (the latest wins).
  delete from feedback where offer_id = o.id and user_id = me;
  insert into feedback (offer_id, user_id, talked, rating, want_again)
  values (o.id, me, did_talk,
          case p_result when 'good' then 'good' when 'not_soon' then 'notReally' end,
          case p_result when 'good' then true when 'not_soon' then false end);
  update match_offers
  set talked = case when did_talk then true else coalesce(match_offers.talked, false) end,
      ended_a = ended_a or me = user_a, ended_b = ended_b or me = user_b,
      updated_at = now()
  where id = o.id;
  if p_result = 'not_soon' then
    insert into pair_snoozes (from_user, to_user, until)
    values (me, other, now() + interval '7 days')
    on conflict (from_user, to_user) do update set until = excluded.until;
  end if;
end;
$$;
revoke all on function public.call_feedback(uuid, text) from public, anon;
grant execute on function public.call_feedback(uuid, text) to authenticated;

-- Older app: a direct feedback insert also counts as "we talked".
create or replace function public.feedback_marks_talked()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.talked and new.offer_id is not null then
    update match_offers set talked = true where id = new.offer_id and status = 'accepted';
  end if;
  return new;
end;
$$;
drop trigger if exists feedback_marks_talked on public.feedback;
create trigger feedback_marks_talked after insert on public.feedback
  for each row execute function public.feedback_marks_talked();

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
           -- Only real talks (someone said "we talked"), not just two yeses.
           (select max(o.accepted_at) from match_offers o
            where o.status = 'accepted' and o.talked
              and o.user_a = least(p_user, a.user_id)
              and o.user_b = greatest(p_user, a.user_id)) as last_talk
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and not is_blocked_between(p_user, a.user_id)
      -- "Not soon" after a call (either side asked): not offered for a while.
      and not exists (
        select 1 from pair_snoozes z
        where z.until > now()
          and ((z.from_user = p_user and z.to_user = a.user_id)
               or (z.from_user = a.user_id and z.to_user = p_user)))
    -- Quietly: quick-connect friends first, then "I'd like to talk"
    -- (either side), then whoever I talked with least recently.
    order by (is_quick(p_user, a.user_id) and is_quick(a.user_id, p_user)) desc,
             wants_to_talk(p_user, a.user_id) desc,
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

-- Routines for one circle: the same one-tap start, with an optional circle.
drop function if exists public.device_start(text, text, integer);
create or replace function public.device_start(
  p_token text, p_mode text default 'free', p_minutes integer default 30,
  p_circle uuid default null)
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
  if p_circle is not null and exists (select 1 from circles where id = p_circle and owner = me) then
    circle := p_circle;
  end if;
  until := now() + make_interval(mins => mins);
  insert into availability (user_id, mode, started_at, expires_at, source, circle_id)
  values (me, p_mode, now(), until, 'manual', circle)
  on conflict (user_id) do update
    set mode = excluded.mode, started_at = now(), expires_at = until,
        source = 'manual', circle_id = circle;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return until;
end;
$$;
grant execute on function public.device_start(text, text, integer, uuid) to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261011000000_after_call') on conflict do nothing;
