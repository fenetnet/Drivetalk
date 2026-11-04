-- DriveBond — friends see when someone is in a call (D-083).
--
--   * A call through the app: from both "yes" until that side ends it
--     (at most 20 minutes, like in_call).
--   * Any other phone call (regular or e.g. WhatsApp) while I'm available:
--     the phone's background service says "in a call" / "call ended". No
--     number, no who, no call log — just yes/no, renewed every 2 minutes and
--     gone by itself after 3.
--   * Someone in a call is never offered to anyone.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 22 $$;
grant execute on function public.schema_version() to anon, authenticated;

alter table public.availability add column if not exists call_until timestamptz;
alter table public.availability add column if not exists phone_until timestamptz;

-- A call through the app starts / ends → mark it on both sides' availability.
create or replace function public.mark_app_call()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted'
     and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
    update availability set call_until = now() + interval '20 minutes'
    where user_id in (new.user_a, new.user_b);
  end if;
  if tg_op = 'UPDATE' then
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
drop trigger if exists match_offers_app_call on public.match_offers;
create trigger match_offers_app_call
  after insert or update of status, ended_a, ended_b on public.match_offers
  for each row execute function public.mark_app_call();

-- On another phone call right now?
create or replace function public.on_phone(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from availability
    where user_id = p_user and phone_until > now()
  );
$$;
revoke all on function public.on_phone(uuid) from public, anon, authenticated;

-- The phone's background service: "in a call" (true) / "call ended" (false).
create or replace function public.device_phone_call(p_token text, p_on boolean)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return 'bad_token'; end if;
  update availability
  set phone_until = case when p_on then now() + interval '3 minutes' else null end
  where user_id = me;
  return 'ok';
end;
$$;
grant execute on function public.device_phone_call(text, boolean) to anon, authenticated;

-- Find ONE friend for this user — never someone in a call.
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
  -- A question nobody answered in time is over (its quiet minutes count
  -- from when it ran out).
  update match_offers set status = 'expired', updated_at = expires_at
  where status = 'pending' and expires_at <= now();
  select * into mine from availability where user_id = p_user and expires_at > now();
  if not found then return 0; end if;
  if has_open_offer(p_user) or in_call(p_user) or on_phone(p_user) then return 0; end if;
  -- A quiet gap: after a question that didn't become a call (no / no
  -- answer / cancelled), nothing new for me for 5 minutes.
  if quiet_gap(p_user) or asked_enough(p_user, mine.started_at) then return 0; end if;

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
      -- 0 on either side = never offered.
      and rating_of(p_user, a.user_id) > 0
      and rating_of(a.user_id, p_user) > 0
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
             -- how much both want to talk (0–5 each, 3 when not set)
             rating_of(p_user, a.user_id) + rating_of(a.user_id, p_user) desc,
             last_talk asc nulls first,
             random()
  loop
    if not in_audience(mine.circle_id, other.user_id)
       or not in_audience(other.circle_id, p_user)
       or has_open_offer(other.user_id)
       or in_call(other.user_id)
       or on_phone(other.user_id)
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
      -- A question waits 2 minutes for answers, then it's over.
      insert into match_offers (user_a, user_b, expires_at)
      values (lo, hi, least(mine.expires_at, other.expires_at, now() + interval '2 minutes'))
      on conflict do nothing;
    end if;
    return 1;
  end loop;
  return 0;
end;
$$;
revoke all on function public.create_offers_for(uuid) from public, anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261022000000_in_a_call') on conflict do nothing;
