-- DriveBond — security round 2 (review of 2026-10-30, D-164).
--
-- 1. A phone number nobody verified (no SMS — D-134) no longer opens the
--    door by itself: "they have my number and I have theirs" skips the
--    friend's approval only when no other account claims the same number.
--    Before, someone who typed a friend's number became a full friend at
--    once (and even replaced the real one on screen).
-- 2. "Connects at once" (auto_yes_status) only names friends I may see as
--    free (not hidden, not anonymous, in my audience).
-- 3. Someone still waiting for approval sees neither the photo nor "last
--    seen" of the person who hasn't approved them; hidden status hides
--    "last seen" too.
-- 4. Contact searches count numbers, not calls (20000 numbers a day): no
--    mapping of everyone's phone number from free accounts.
-- 5. Usage events: at most 500 an hour per account.
-- 6. Leftover table rights for `anon` (blocked by RLS anyway) removed.
-- 7. Logic: ⚡ respects a chosen pause and unapproved friends; "X is on
--    the way" never to a friend I rated 0; two lookups only over my
--    friends (speed); an offer born accepted wakes both phones.
-- Older apps keep working: same functions, same answers for real friends.

-- ------------------------------------------------------------ 1. numbers

-- My number is mine alone: no other account claims it.
create or replace function public.number_unique(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from phone_numbers mine
                 where mine.user_id = p_user and mine.phone_hash is not null)
     and not exists (
       select 1 from phone_numbers mine
       join phone_numbers other
         on other.phone_hash = mine.phone_hash and other.user_id <> mine.user_id
       where mine.user_id = p_user);
$$;
revoke all on function public.number_unique(uuid) from public, anon, authenticated;

create or replace function public.add_contacts(p_users uuid[])
returns table (display_name text)
language plpgsql security definer set search_path = public as $$
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
      and not are_connected(me, pn.user_id)
      and not kept_apart(me, pn.user_id)
  loop
    insert into connections (user_a, user_b, pending_for)
    values (least(me, other.user_id), greatest(me, other.user_id),
            -- They have my number saved: no approval needed — unless
            -- another account claims the same number (then they decide).
            case when number_unique(me) and exists (
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

create table if not exists public.contact_search_counts (
  user_id uuid not null references public.profiles (id) on delete cascade,
  at timestamptz not null default now(),
  n integer not null
);
create index if not exists contact_search_counts_user_at
  on public.contact_search_counts (user_id, at);
alter table public.contact_search_counts enable row level security;
revoke all on public.contact_search_counts from public, anon, authenticated;

create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  n integer := coalesce(array_length(p_hashes, 1), 0);
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;
  if n > 5000 then raise exception 'too_many_contacts'; end if;
  -- Numbers, not calls: a full phone book a few times a day is fine;
  -- sweeping the country's numbers is not.
  if coalesce((select sum(c.n) from contact_search_counts c
               where c.user_id = me and c.at > now() - interval '1 day'), 0) + n > 20000 then
    raise exception 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  if exists (select 1 from profiles where id = me) then
    insert into contact_search_counts (user_id, n) values (me, n);
  end if;
  delete from contact_hashes where owner = me;
  if n = 0 then return; end if;
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  -- Waiting for me, and I have their number: approved — unless another
  -- account claims that number too (then I choose on their card).
  update connections c set pending_for = null
  where c.pending_for = me
    and number_unique(case when c.user_a = me then c.user_b else c.user_a end)
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
        and not blocked_any(me, pn.user_id)
      order by pn.phone_hash,
               replaced_account(pn.user_id) asc,
               are_connected(me, pn.user_id) desc,
               pr.last_seen_at desc
    ) x
    where x.is_friend or not kept_apart(me, x.user_id)
    order by x.display_name;
end;
$$;

-- A newer account with the same number replaces the old one on my screen
-- only once I approved it (an unapproved claim never hides a real friend).
create or replace function private.replaced_for(p_viewer uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from phone_numbers mine
    join profiles me on me.id = mine.user_id
    join phone_numbers other
      on other.phone_hash = mine.phone_hash and other.user_id <> mine.user_id
    join profiles newer on newer.id = other.user_id
    where mine.user_id = p_user
      and mine.phone_hash is not null
      and are_connected(p_viewer, other.user_id)
      and not awaits_approval(p_viewer, other.user_id)
      and (
        newer.created_at > me.last_seen_at
        or (me.last_seen_at < now() - interval '1 day'
            and newer.last_seen_at > me.last_seen_at)));
$$;

-- ------------------------------------------------------------ 2. ⚡ status

create or replace function public.auto_yes_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'on', (select auto_yes from profiles where id = me),
    'min', (select auto_yes_min from profiles where id = me),
    'instant', coalesce((
      select jsonb_agg(a.user_id)
      from connections c
      join availability a
        on a.user_id = case when c.user_a = me then c.user_b else c.user_a end
      join profiles p on p.id = a.user_id and p.auto_yes
      where me in (c.user_a, c.user_b) and c.pending_for is null
        and a.mode = 'driving' and a.expires_at > now()
        -- Only friends I may see as free right now (D-164).
        and not hides_status(a.user_id)
        and not is_anonymous(a.user_id)
        and sees_free_apart_from_name(me, a)
        -- The first minutes of a trip a tap gets "busy": no ring then.
        and (a.quiet_until is null or a.quiet_until <= now())
        and auto_yes_for(a.user_id, me)), '[]'::jsonb));
end;
$$;

-- ------------------------------------------------------------ 3. photo, last seen

create or replace function private.can_see_avatar(p_name text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  owner text := split_part(coalesce(p_name, ''), '.', 1);
  other uuid;
begin
  if me is null then return false; end if;
  if owner = me::text then return true; end if;
  begin
    other := owner::uuid;
  exception when others then
    return false;
  end;
  -- Not before they approved me (D-164).
  return are_connected(me, other) and not awaits_approval(other, me)
     and not is_blocked_between(me, other);
end;
$$;

create or replace function public.friends_activity()
returns table (user_id uuid, days integer)
language sql stable security definer set search_path = public as $$
  select p.id, floor(extract(epoch from now() - p.last_seen_at) / 86400)::integer
  from profiles p
  where p.id in (select friend_ids(auth.uid()))
    and p.id <> auth.uid()
    and not is_blocked_between(auth.uid(), p.id)
    -- Not before they approved me, and not when they hide their status.
    and not awaits_approval(p.id, auth.uid())
    and not hides_status(p.id);
$$;

-- ------------------------------------------------------------ 5. events

create or replace function public.log_event(p_name text, p_ms integer default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if not exists (select 1 from profiles where id = auth.uid()) then return; end if;
  if (select count(*) from app_events
      where user_id = auth.uid() and created_at > now() - interval '1 hour') >= 500 then
    return;
  end if;
  insert into app_events (user_id, name, ms) values (auth.uid(), p_name, p_ms);
end;
$$;

-- ------------------------------------------------------------ 6. anon rights

revoke all on public.circles, public.circle_members, public.contact_hashes,
  public.crash_reports, public.device_tokens from anon;


-- ------------------------------------------------------------ 7. logic fixes

-- ⚡ never overrides a pause I chose myself, nor a friend I haven't
-- approved yet: a tap then asks, as before (D-108, D-164).
create or replace function public.auto_yes_for(p_user uuid, p_from uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles p join availability a on a.user_id = p.id
    where p.id = p_user and p.auto_yes
      and a.mode = 'driving' and a.expires_at > now() and a.missed_at is null
      and rating_of(p_user, p_from) >= p.auto_yes_min)
    and exists (select 1 from phone_numbers where user_id = p_user)
    and are_connected(p_user, p_from)
    and not awaits_approval(p_user, p_from)
    and not exists (select 1 from pair_snoozes z
                    where z.chosen and z.until > now()
                      and z.from_user = p_user and z.to_user = p_from)
    and not is_blocked_between(p_user, p_from)
    and not in_call(p_user)
    and not on_phone(p_user)
    and not in_quiet_hours(p_user);
$$;

create or replace function public.trip_push_claim(p_user uuid)
returns table (friend_id uuid, push_token text, from_name text)
language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  my_name text;
begin
  select * into mine from availability a where a.user_id = p_user and a.expires_at > now();
  if not found or mine.mode <> 'driving' or mine.missed_at is not null
     or coalesce(mine.quiet_until > now(), false) then
    return;
  end if;
  if not coalesce((select p.trip_notify from profiles p where p.id = p_user), true)
     or is_anonymous(p_user) or hides_status(p_user) then
    return;
  end if;
  select p.display_name into my_name from profiles p where p.id = p_user;
  return query
  with targets as (
    select f.id as fid from profiles f
    -- Only my friends (fast with many users), never one I rated 0.
    where f.id in (select friend_ids(p_user))
      and f.id <> p_user
      and rating_of(p_user, f.id) <> 0
      -- Friends whose ⚡ auto-yes covers me (D-161); old quick-connect
      -- pairs still count until everyone has the new app.
      and ((f.auto_yes and rating_of(f.id, p_user) >= f.auto_yes_min)
           or (is_quick(p_user, f.id) and is_quick(f.id, p_user)))
      and sees_free_apart_from_name(f.id, mine)
      and not is_anonymous(f.id)
      and not in_quiet_hours(f.id)
      and rating_of(f.id, p_user) <> 0
      and not exists (select 1 from availability a
                      where a.user_id = f.id and a.expires_at > now())
      and not exists (select 1 from pair_snoozes s
                      where s.chosen and s.until > now()
                        and ((s.from_user = f.id and s.to_user = p_user)
                             or (s.from_user = p_user and s.to_user = f.id)))
      and not exists (select 1 from trip_pushes t
                      where t.owner = p_user and t.member = f.id
                        and t.sent_at > now() - interval '20 hours')
      and exists (select 1 from push_tokens pt where pt.user_id = f.id)
  ), marked as (
    insert into trip_pushes (owner, member, sent_at)
    select p_user, targets.fid, now() from targets
    on conflict (owner, member) do update set sent_at = excluded.sent_at
    returning trip_pushes.member as mid
  )
  select marked.mid, pt.token, my_name
  from marked join push_tokens pt on pt.user_id = marked.mid;
end;
$$;
revoke all on function public.trip_push_claim(uuid) from public, anon, authenticated;
grant execute on function public.trip_push_claim(uuid) to service_role;

-- Only my friends (it ran over every free user on each refresh).
create or replace function public.askable_friends()
returns setof uuid language sql stable security definer set search_path = public as $$
  select a.user_id from availability a
  where a.user_id in (select friend_ids(auth.uid()))
    and a.user_id <> auth.uid()
    and a.expires_at > now()
    and ask_check(auth.uid(), a.user_id, false) = 'ok';
$$;

-- An offer born accepted (both have ⚡ while driving): both phones are
-- woken at once, not only by the next background check.
create or replace function public.offer_push()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    -- The one who tapped already said yes: only the other side is asked.
    if new.a_response is distinct from 'accept' then
      perform push_queue(new.user_a, 'sync', '{}'::jsonb, 'offer:' || new.id || ':' || new.user_a);
    end if;
    if new.b_response is distinct from 'accept' then
      perform push_queue(new.user_b, 'sync', '{}'::jsonb, 'offer:' || new.id || ':' || new.user_b);
    end if;
  elsif new.status = 'accepted'
        and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
    perform push_queue(new.user_a, 'sync', '{}'::jsonb, 'call:' || new.id || ':' || new.user_a);
    perform push_queue(new.user_b, 'sync', '{}'::jsonb, 'call:' || new.id || ':' || new.user_b);
  end if;
  return null;
end;
$$;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 68 $$;

insert into public.drivetalk_migrations (name)
values ('20261068000000_security_round2') on conflict do nothing;

notify pgrst, 'reload schema';
