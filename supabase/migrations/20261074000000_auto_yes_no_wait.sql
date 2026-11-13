-- DriveBond — ⚡ on both sides: no 5-second countdown (owner, 2026-11-04).
--
-- When both friends have ⚡ "yes automatically" for each other and the app
-- connects them, the call starts as soon as both phones know — no 5
-- seconds to cancel. Old quick-connect pairs (D-026) keep their 5 seconds.
-- Older apps: nothing to update ("connecting…" is just shorter).

alter table public.match_offers add column if not exists no_wait boolean not null default false;

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
    -- ⚡ on both sides: connected at once, whoever's phone starts calls;
    -- no daily limit and no 5 seconds (owner, D-153, 2026-11-04).
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
                                quick, accepted_at, last_talk, no_wait)
      values (lo, hi, least(mine.expires_at, other.expires_at), 'accepted', 'accept', 'accept',
              true, now(), other.last_talk,
              -- ⚡ on both sides: no 5 seconds (owner, 2026-11-04)
              auto_mine and auto_theirs);
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
  set not_before = greatest(seen_a, seen_b)
                   + case when no_wait then interval '0 seconds' else interval '5 seconds' end,
      updated_at = now()
  where id = p_offer and quick and status = 'accepted' and not_before is null
    and seen_a is not null and seen_b is not null;
end;
$$;
revoke all on function public.mark_seen(uuid, uuid) from public, anon, authenticated;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 74 $$;

insert into public.drivetalk_migrations (name)
values ('20261074000000_auto_yes_no_wait') on conflict do nothing;

notify pgrst, 'reload schema';
