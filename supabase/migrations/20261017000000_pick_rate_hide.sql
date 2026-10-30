-- DriveTalk — I choose who to add, how much I want to talk, and whether
-- my status is shown (D-074).
--
--   * Contacts: nobody is connected automatically any more. A search only
--     lists contacts who use DriveTalk; I pick who to add (connected at
--     once). Anyone can remove anyone, and a removed person is never
--     suggested or added again from contacts (only by an invitation link).
--   * Rating 0–5 per friend (only I see mine): 0 = never offer, 5 = first.
--     Offers rank pairs by both ratings; a 0 on either side = no offers.
--   * "Hide my status": friends don't see when I'm free, and I don't see
--     theirs — offers still happen when both are free.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 17 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- ------------------------------------------------------------ removed pairs

create table if not exists public.removed_pairs (
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
alter table public.removed_pairs enable row level security;
revoke all on public.removed_pairs from anon, authenticated;

-- Any removal (remove, block) is remembered; any new connection (invitation,
-- unblock, a pick) clears it.
create or replace function public.remember_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if exists (select 1 from profiles where id = old.user_a)
       and exists (select 1 from profiles where id = old.user_b) then
      insert into removed_pairs (user_a, user_b) values (old.user_a, old.user_b)
      on conflict do nothing;
    end if;
    return old;
  end if;
  delete from removed_pairs where user_a = new.user_a and user_b = new.user_b;
  return new;
end;
$$;
drop trigger if exists connections_removed on public.connections;
create trigger connections_removed after insert or delete on public.connections
  for each row execute function public.remember_removed();

create or replace function public.was_removed(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from removed_pairs
                 where user_a = least(x, y) and user_b = greatest(x, y));
$$;
revoke all on function public.was_removed(uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ contacts

-- Replace my contact hashes (DriveTalk users' numbers only) and list who of
-- my contacts is here and can be added. Connects nobody.
drop function if exists public.find_friends(text[]);
create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from contact_hashes where owner = me;
  if p_hashes is null or array_length(p_hashes, 1) is null then return; end if;
  if array_length(p_hashes, 1) > 5000 then raise exception 'too_many_contacts'; end if;
  -- Numbers of people who don't use DriveTalk are dropped right here.
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  return query
    select pn.user_id, pr.display_name
    from phone_numbers pn
    join profiles pr on pr.id = pn.user_id
    where pn.user_id <> me
      and pn.phone_hash in (select hash from contact_hashes where owner = me)
      and not is_blocked_between(me, pn.user_id)
      and not are_connected(me, pn.user_id)
      and not was_removed(me, pn.user_id)
    order by pr.display_name;
end;
$$;
revoke all on function public.find_friends(text[]) from public, anon;
grant execute on function public.find_friends(text[]) to authenticated;

-- Add the people I picked (only ones really in my contacts). Connected at once.
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
      and not is_blocked_between(me, pn.user_id)
      and not are_connected(me, pn.user_id)
      and not was_removed(me, pn.user_id)
  loop
    insert into connections (user_a, user_b)
    values (least(me, other.user_id), greatest(me, other.user_id))
    on conflict do nothing;
    display_name := other.display_name;
    return next;
  end loop;
  perform create_offers_for(me);
end;
$$;
revoke all on function public.add_contacts(uuid[]) from public, anon;
grant execute on function public.add_contacts(uuid[]) to authenticated;

-- Older app versions: hashes are kept (users only), nobody is connected.
create or replace function public.sync_contacts(p_hashes text[])
returns table (display_name text)
language sql security definer set search_path = public as $$
  select null::text from public.find_friends(p_hashes) where false;
$$;
revoke all on function public.sync_contacts(text[]) from public, anon;
grant execute on function public.sync_contacts(text[]) to authenticated;

-- Requests are no longer used: picking someone connects at once.
update public.connect_requests set status = 'declined', updated_at = now()
where status = 'pending';

-- ------------------------------------------------------------ ratings

create table if not exists public.friend_ratings (
  owner uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  friend uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 0 and 5),
  updated_at timestamptz not null default now(),
  primary key (owner, friend)
);
alter table public.friend_ratings enable row level security;
revoke all on public.friend_ratings from anon, authenticated;
grant select on public.friend_ratings to authenticated;
drop policy if exists "ratings: mine" on public.friend_ratings;
create policy "ratings: mine" on public.friend_ratings
  for select to authenticated using (owner = auth.uid());

create or replace function public.set_rating(p_friend uuid, p_rating integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_rating is null or p_rating < 0 or p_rating > 5 then raise exception 'invalid_rating'; end if;
  if not are_connected(me, p_friend) then raise exception 'not_connected'; end if;
  insert into friend_ratings (owner, friend, rating) values (me, p_friend, p_rating)
  on conflict (owner, friend) do update set rating = excluded.rating, updated_at = now();
  perform create_offers_for(me);
end;
$$;
revoke all on function public.set_rating(uuid, integer) from public, anon;
grant execute on function public.set_rating(uuid, integer) to authenticated;

-- How much x wants to talk with y (3 when not set).
create or replace function public.rating_of(x uuid, y uuid)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select rating from friend_ratings where owner = x and friend = y), 3);
$$;
revoke all on function public.rating_of(uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ hide my status

alter table public.profiles add column if not exists hide_status boolean not null default false;

create or replace function public.set_hide_status(p_hide boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update profiles set hide_status = coalesce(p_hide, false) where id = auth.uid();
end;
$$;
revoke all on function public.set_hide_status(boolean) from public, anon;
grant execute on function public.set_hide_status(boolean) to authenticated;

create or replace function public.hides_status(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select hide_status from profiles where id = p_user), false);
$$;
revoke all on function public.hides_status(uuid) from public, anon;
grant execute on function public.hides_status(uuid) to authenticated;

drop policy if exists availability_select on public.availability;
create policy availability_select on public.availability for select to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now()
        and public.are_connected(auth.uid(), user_id)
        and not public.is_blocked_between(auth.uid(), user_id)
        and public.in_audience(circle_id, auth.uid())
        and not public.hides_status(user_id)
        and not public.hides_status(auth.uid()))
  );

-- ------------------------------------------------------------ offers

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
  if has_open_offer(p_user) or in_call(p_user) then return 0; end if;
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
values ('20261017000000_pick_rate_hide') on conflict do nothing;
