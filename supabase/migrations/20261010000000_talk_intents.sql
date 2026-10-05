-- DriveTalk — "I'd like to talk" (D-061).
-- A quiet intent next to a friend: today / this week / until I remove it.
-- The friend is never told. When both are free later, that friend is
-- offered first. Only the owner can see their own intents.

create table if not exists public.talk_intents (
  from_user uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  to_user uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz,           -- null = until I remove it
  primary key (from_user, to_user),
  check (from_user <> to_user)
);
alter table public.talk_intents enable row level security;
drop policy if exists talk_intents_select on public.talk_intents;
create policy talk_intents_select on public.talk_intents for select to authenticated
  using (from_user = auth.uid());
revoke all on public.talk_intents from anon, authenticated;
grant select on public.talk_intents to authenticated;

-- Mark (or update) "I'd like to talk with this friend". p_until null = until removed.
create or replace function public.set_talk_intent(p_user uuid, p_until timestamptz)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not are_connected(me, p_user) then raise exception 'not_connected'; end if;
  insert into talk_intents (from_user, to_user, created_at, expires_at)
  values (me, p_user, now(), p_until)
  on conflict (from_user, to_user) do update
    set created_at = now(), expires_at = excluded.expires_at;
end;
$$;
revoke all on function public.set_talk_intent(uuid, timestamptz) from public, anon;
grant execute on function public.set_talk_intent(uuid, timestamptz) to authenticated;

create or replace function public.clear_talk_intent(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from talk_intents where from_user = auth.uid() and to_user = p_user;
end;
$$;
revoke all on function public.clear_talk_intent(uuid) from public, anon;
grant execute on function public.clear_talk_intent(uuid) to authenticated;

-- Does either of them want to talk (and haven't talked since they said so)?
create or replace function public.wants_to_talk(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from talk_intents t
    where ((t.from_user = x and t.to_user = y) or (t.from_user = y and t.to_user = x))
      and (t.expires_at is null or t.expires_at > now())
      and not exists (
        select 1 from match_offers o
        where o.status = 'accepted' and o.user_a = least(x, y) and o.user_b = greatest(x, y)
          and o.accepted_at > t.created_at)
  );
$$;
revoke all on function public.wants_to_talk(uuid, uuid) from public, anon, authenticated;

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
           (select max(o.accepted_at) from match_offers o
            where o.status = 'accepted'
              and o.user_a = least(p_user, a.user_id)
              and o.user_b = greatest(p_user, a.user_id)) as last_talk
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and not is_blocked_between(p_user, a.user_id)
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

insert into public.drivetalk_migrations (name)
values ('20261010000000_talk_intents') on conflict do nothing;
