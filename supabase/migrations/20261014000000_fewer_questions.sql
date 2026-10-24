-- DriveTalk — fewer questions while driving (D-069).
--
-- Before: after "not now" or no answer, the same friend was offered again
-- after 2 minutes, and the driving service's 4-minute renewal restarted the
-- "trip" each time. Now:
--   * the same friend at most once per trip / free window;
--   * after a question that didn't become a call, 5 quiet minutes;
--   * renewing automatic driving availability keeps the trip's start.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 14 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- Did a question for this user end without a call in the last 5 minutes?
create or replace function public.quiet_gap(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_offers o
    where p_user in (o.user_a, o.user_b)
      and o.status in ('declined', 'expired', 'cancelled')
      and o.updated_at > now() - interval '5 minutes');
$$;
revoke all on function public.quiet_gap(uuid) from public, anon, authenticated;

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
  -- A quiet gap: after a question that didn't become a call (no / no
  -- answer / cancelled), nothing new for me for 5 minutes.
  if quiet_gap(p_user) then return 0; end if;

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
       or in_call(other.user_id)
       or quiet_gap(other.user_id) then
      continue;
    end if;
    lo := least(p_user, other.user_id);
    hi := greatest(p_user, other.user_id);
    if exists (
      select 1 from match_offers o
      where o.user_a = lo and o.user_b = hi
        and ((o.status = 'declined' and o.updated_at > now() - interval '2 minutes')
             -- after a call: not the same pair again for 30 minutes
             or (o.status = 'accepted' and o.accepted_at > now() - interval '30 minutes')
             -- once per trip / free window: a pair that already got a
             -- question (and didn't talk) isn't asked again until one of
             -- them starts a new window
             or (o.status in ('declined', 'expired', 'cancelled')
                 and o.created_at >= greatest(mine.started_at, other.started_at)))
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

-- Automatic driving: the 4-minute renewal extends the same trip (its start
-- stays), so "once per trip" really means once per trip.
create or replace function public.auto_start(p_token text, p_minutes integer default 120)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  mins integer := least(greatest(coalesce(p_minutes, 120), 15), 180);
  cur availability;
begin
  if me is null then return 'bad_token'; end if;
  select * into cur from availability where user_id = me and expires_at > now();
  if found and cur.source = 'manual' then
    return 'already_available';
  end if;
  insert into availability (user_id, mode, started_at, expires_at, source)
  values (me, 'driving', now(), now() + make_interval(mins => mins), 'auto')
  on conflict (user_id) do update
    set mode = 'driving',
        started_at = case
          when availability.source = 'auto' and availability.expires_at > now()
            and availability.started_at > now() - interval '2 hours 50 minutes'
          then availability.started_at else now() end,
        expires_at = least(
          now() + make_interval(mins => mins),
          case
            when availability.source = 'auto' and availability.expires_at > now()
              and availability.started_at > now() - interval '2 hours 50 minutes'
            then availability.started_at else now() end + interval '3 hours'),
        source = 'auto';
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return 'available';
end;
$$;
grant execute on function public.auto_start(text, integer) to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261014000000_fewer_questions') on conflict do nothing;
