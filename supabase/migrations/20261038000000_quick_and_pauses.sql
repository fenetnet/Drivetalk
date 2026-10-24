-- DriveBond — quick connect isn't stopped by the automatic pause; each
-- friend's card shows my pause, with "cancel" (D-113).
--
-- - After a call, the pair gets 3 quiet days by itself (D-108). For
--   quick-connect friends (both turned it on) that automatic pause no longer
--   stops quick connect; only a pause someone chose ("in a week") does.
-- - My pause for a friend ("no suggestions until Thursday") is shown on the
--   friend's card and can be cancelled. The other side's choice stays
--   private (never shown).

alter table public.pair_snoozes add column if not exists chosen boolean not null default false;

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
    delete from pair_snoozes where from_user = me and to_user = other;
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
      -- friends only by a pause someone chose (D-113).
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

-- My pauses (friends I'm not offered until …). Mine only.
create or replace function public.my_pauses()
returns table(user_id uuid, until timestamptz, chosen boolean)
language sql stable security definer set search_path = public as $$
  select z.to_user, z.until, z.chosen
  from pair_snoozes z
  where z.from_user = auth.uid() and z.until > now();
$$;
revoke all on function public.my_pauses() from public, anon;
grant execute on function public.my_pauses() to authenticated;

-- "Cancel the pause" on a friend's card: mine, and the automatic one on
-- their side too (a pause they chose stays — it's theirs).
create or replace function public.clear_pause(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from pair_snoozes
  where (from_user = me and to_user = p_user)
     or (from_user = p_user and to_user = me and not chosen);
  perform create_offers_for(me);
end;
$$;
revoke all on function public.clear_pause(uuid) from public, anon;
grant execute on function public.clear_pause(uuid) to authenticated;

-- Last: the version says 38 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 38 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261038000000_quick_and_pauses') on conflict do nothing;
