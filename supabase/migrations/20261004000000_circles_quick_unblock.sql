-- DriveTalk — owner feedback round (2026-10-04):
-- * After "not now", offers come back after a short pause (2 minutes; after
--   a call, 30 minutes), and
--   phones "nudge" while free, so a new offer appears without restarting.
-- * Unblock (and the connection comes back if there was one).
-- * Private circles: "available only to family", and "quick connect" circles
--   — when BOTH have each other in a quick circle and both are free, the
--   match is accepted at once (the app still shows a 5-second cancel).
--   At most one quick connect per pair per day.

-- ------------------------------------------------------------ circles

create table if not exists public.circles (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  name text not null check (char_length(btrim(name)) between 1 and 30),
  quick boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists circles_owner_idx on public.circles (owner);

create table if not exists public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  member uuid not null references public.profiles (id) on delete cascade,
  primary key (circle_id, member)
);
create index if not exists circle_members_member_idx on public.circle_members (member);

alter table public.circles enable row level security;
alter table public.circle_members enable row level security;

-- Circles are private: only the owner sees and edits them.
create policy circles_all on public.circles for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
-- Only my own circles, and only people I'm connected to.
create policy circle_members_select on public.circle_members for select to authenticated
  using (exists (select 1 from circles c where c.id = circle_id and c.owner = auth.uid()));
create policy circle_members_insert on public.circle_members for insert to authenticated
  with check (
    exists (select 1 from circles c where c.id = circle_id and c.owner = auth.uid())
    and public.are_connected(auth.uid(), member)
  );
create policy circle_members_delete on public.circle_members for delete to authenticated
  using (exists (select 1 from circles c where c.id = circle_id and c.owner = auth.uid()));

grant select, insert, update, delete on public.circles to authenticated;
grant select, insert, delete on public.circle_members to authenticated;

-- x put y in one of x's quick-connect circles.
create or replace function public.is_quick(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from circles c join circle_members m on m.circle_id = c.id
    where c.owner = x and c.quick and m.member = y
  );
$$;

-- y may see / be offered x's availability (no circle, or y is in it).
create or replace function public.in_audience(p_circle uuid, viewer uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_circle is null
    or exists (select 1 from circle_members m where m.circle_id = p_circle and m.member = viewer);
$$;

-- ------------------------------------------------------------ availability

alter table public.availability
  add column if not exists circle_id uuid references public.circles (id) on delete set null;

drop policy if exists availability_select on public.availability;
create policy availability_select on public.availability for select to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now()
        and public.are_connected(auth.uid(), user_id)
        and not public.is_blocked_between(auth.uid(), user_id)
        and public.in_audience(circle_id, auth.uid()))
  );

alter table public.match_offers add column if not exists quick boolean not null default false;

-- "I'm free now", optionally only for one of my circles.
drop function if exists public.set_availability(text, integer);
create or replace function public.set_availability(
  p_mode text, p_minutes integer, p_circle uuid default null)
returns public.availability language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  result availability;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_minutes is null or p_minutes < 1 or p_minutes > 180 then
    raise exception 'invalid_minutes';
  end if;
  if p_circle is not null and not exists (
    select 1 from circles where id = p_circle and owner = me) then
    raise exception 'invalid_circle';
  end if;
  insert into availability (user_id, mode, started_at, expires_at, source, circle_id)
  values (me, p_mode, now(), now() + make_interval(mins => p_minutes), 'manual', p_circle)
  on conflict (user_id) do update
    set mode = excluded.mode,
        started_at = excluded.started_at,
        expires_at = excluded.expires_at,
        source = 'manual',
        circle_id = excluded.circle_id
  returning * into result;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return result;
end;
$$;
revoke all on function public.set_availability(text, integer, uuid) from public, anon;
grant execute on function public.set_availability(text, integer, uuid) to authenticated;

-- Offers: circles respected both ways; 2-minute pause after "not now";
-- mutual quick-connect → accepted at once (max once per pair per day).
create or replace function public.create_offers_for(p_user uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  other record;
  created integer := 0;
  lo uuid;
  hi uuid;
  quick boolean;
begin
  select * into mine from availability where user_id = p_user and expires_at > now();
  if not found then return 0; end if;
  for other in
    select a.user_id, a.expires_at, a.circle_id
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and not is_blocked_between(p_user, a.user_id)
  loop
    if not in_audience(mine.circle_id, other.user_id)
       or not in_audience(other.circle_id, p_user) then
      continue;
    end if;
    lo := least(p_user, other.user_id);
    hi := greatest(p_user, other.user_id);
    if exists (
      select 1 from match_offers o
      where o.user_a = lo and o.user_b = hi
        and (o.status = 'pending'
             or (o.status = 'declined' and o.updated_at > now() - interval '2 minutes')
             -- after a call: not the same pair again for 30 minutes
             or (o.status = 'accepted' and o.updated_at > now() - interval '30 minutes'))
    ) then
      continue;
    end if;
    quick := is_quick(p_user, other.user_id) and is_quick(other.user_id, p_user)
      and not exists (
        select 1 from match_offers o
        where o.user_a = lo and o.user_b = hi and o.quick
          and o.created_at > now() - interval '1 day');
    if quick then
      insert into match_offers (user_a, user_b, expires_at, status, a_response, b_response, quick)
      values (lo, hi, least(mine.expires_at, other.expires_at), 'accepted', 'accept', 'accept', true);
    else
      insert into match_offers (user_a, user_b, expires_at)
      values (lo, hi, least(mine.expires_at, other.expires_at))
      on conflict do nothing;
    end if;
    created := created + 1;
  end loop;
  return created;
end;
$$;

-- The app calls this every few seconds while I'm free, so a new offer
-- appears once a pause ends (nobody has to restart anything).
create or replace function public.nudge_offers()
returns integer language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return create_offers_for(auth.uid());
end;
$$;
revoke all on function public.nudge_offers() from public, anon;
grant execute on function public.nudge_offers() to authenticated;

-- Background check while driving: also nudges, and reports fresh quick
-- connects ("kind" = 'ask' or 'quick').
drop function if exists public.auto_offers(text);
create or replace function public.auto_offers(p_token text)
returns table (offer_id uuid, other_name text, kind text)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return; end if;
  perform create_offers_for(me);
  return query
    select o.id, p.display_name,
           case when o.quick then 'quick' else 'ask' end
    from match_offers o
    join profiles p on p.id = case when o.user_a = me then o.user_b else o.user_a end
    where me in (o.user_a, o.user_b)
      and not is_blocked_between(o.user_a, o.user_b)
      and (
        (o.status = 'pending' and o.expires_at > now()
         and (case when o.user_a = me then o.a_response else o.b_response end) is null)
        or (o.quick and o.status = 'accepted' and o.updated_at > now() - interval '3 minutes')
      )
    order by o.created_at;
end;
$$;
grant execute on function public.auto_offers(text) to anon, authenticated;

-- ------------------------------------------------------------ unblock

alter table public.blocks add column if not exists was_connected boolean not null default false;

create or replace function public.block_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  had boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_user = me then return; end if;
  had := are_connected(me, p_user);
  insert into blocks (blocker, blocked, was_connected) values (me, p_user, had)
  on conflict (blocker, blocked) do nothing;
  delete from connections where user_a = least(me, p_user) and user_b = greatest(me, p_user);
  delete from circle_members m using circles c
  where m.circle_id = c.id and c.owner = me and m.member = p_user;
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and user_a = least(me, p_user) and user_b = greatest(me, p_user);
end;
$$;

-- People I blocked (first name only, so I can find them to unblock).
create or replace function public.my_blocks()
returns table (user_id uuid, display_name text, gender text)
language sql stable security definer set search_path = public as $$
  select b.blocked, p.display_name, p.gender
  from blocks b join profiles p on p.id = b.blocked
  where b.blocker = auth.uid()
  order by b.created_at desc;
$$;

-- Unblock; if we were connected before, the connection comes back
-- (unless they blocked me too).
create or replace function public.unblock_user(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  b blocks;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from blocks where blocker = me and blocked = p_user returning * into b;
  if not found then return 'not_blocked'; end if;
  if b.was_connected and not is_blocked_between(me, p_user) then
    insert into connections (user_a, user_b)
    values (least(me, p_user), greatest(me, p_user))
    on conflict do nothing;
    return 'reconnected';
  end if;
  return 'unblocked';
end;
$$;

revoke all on function public.is_quick(uuid, uuid) from public, anon;
revoke all on function public.in_audience(uuid, uuid) from public, anon;
grant execute on function public.in_audience(uuid, uuid) to authenticated;
revoke all on function public.my_blocks() from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
grant execute on function public.my_blocks() to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.circles, public.circle_members;
exception when others then
  raise notice 'realtime: %', sqlerrm;
end;
$$;
