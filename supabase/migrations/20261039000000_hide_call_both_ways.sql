-- DriveBond — "hide when I'm in a call" works both ways (D-114), and two
-- fixes to the pauses after a call.
--
-- Whoever hides themselves while in a call also doesn't see that friends
-- are in a call: a friend who is in a call simply doesn't show as free to
-- them (like everyone else who can't talk right now). Fair for both sides.

-- Can p_viewer see p_owner's free time, apart from the "without my name"
-- rule? (Same rules as the availability policy below.)
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
    and not ((hides_call(a.user_id) or hides_call(p_viewer))
             and coalesce(a.call_until > now() or a.phone_until > now(), false));
$$;
revoke all on function public.sees_free_apart_from_name(uuid, availability) from public, anon, authenticated;

-- The policy (helpers in schema private, D-110).
drop policy if exists availability_select on public.availability;
create policy availability_select on public.availability for select to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now()
        and missed_at is null
        and private.are_connected(auth.uid(), user_id)
        and not private.is_blocked_between(auth.uid(), user_id)
        and private.in_audience(circle_id, auth.uid())
        and not private.hides_status(user_id)
        and not private.hides_status(auth.uid())
        and private.sees_availability(user_id)
        and not private.awaits_approval(user_id, auth.uid())
        and not ((private.hides_call(user_id) or private.hides_call(auth.uid()))
                 and coalesce(call_until > now() or phone_until > now(), false))
        and not private.is_anonymous(user_id)
        and not private.is_anonymous(auth.uid()))
  );


-- ------------------------------------------------------------ pauses
--
-- Two fixes to the pauses after a call (D-113):
-- - Quick-connect friends: the automatic 3 quiet days let only quick
--   connect through, not a regular "talk?" question.
-- - "Any time" after a call also removes the automatic pause on the other
--   side (like "cancel the pause" on the friend's card).

create or replace function public.after_call(p_offer uuid, p_days integer, p_talked boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  other uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_days is null or p_days < 0 or p_days > 30 then raise exception 'invalid_days'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) or o.status <> 'accepted' then
    raise exception 'not_found';
  end if;
  other := case when me = o.user_a then o.user_b else o.user_a end;
  update match_offers
  set talked = coalesce(p_talked, true),
      ended_a = ended_a or me = user_a, ended_b = ended_b or me = user_b,
      updated_at = now()
  where id = o.id;
  if p_days = 0 then
    -- "Any time": mine, and the automatic pause on their side (a pause
    -- they chose stays — it's theirs). Same as "cancel the pause".
    delete from pair_snoozes
    where (from_user = me and to_user = other)
       or (from_user = other and to_user = me and not chosen);
  else
    insert into pair_snoozes (from_user, to_user, until, chosen)
    values (me, other, now() + make_interval(days => p_days), true)
    on conflict (from_user, to_user) do update set until = excluded.until, chosen = true;
  end if;
end;
$$;

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

-- Last: the version says 39 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 39 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261039000000_hide_call_both_ways') on conflict do nothing;
