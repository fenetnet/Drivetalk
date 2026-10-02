-- DriveTalk — Phase 2: real two-user test.
--
-- Principles:
-- * Row Level Security on every table. Clients only read what they may see.
-- * Sensitive writes go through SECURITY DEFINER functions with explicit checks.
-- * Availability always expires (expires_at, capped at 3 hours) and is hidden
--   the moment it expires, even if nothing cleans it up.
-- * No location, no phone numbers, no emails are stored here.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- tables

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 40),
  gender text not null default 'other' check (gender in ('female', 'male', 'other')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  inviter_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_by uuid references public.profiles (id) on delete set null,
  accepted_at timestamptz
);
create index invitations_inviter_idx on public.invitations (inviter_id);

-- One row per pair, always stored as (smaller id, larger id).
create table public.connections (
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  via_invitation uuid references public.invitations (id) on delete set null,
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index connections_b_idx on public.connections (user_b);

create table public.availability (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  mode text not null check (mode in ('driving', 'walking', 'breakTime', 'free')),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > started_at),
  check (expires_at <= started_at + interval '3 hours 1 minute')
);

create table public.match_offers (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles (id) on delete cascade,
  user_b uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  a_response text check (a_response in ('accept', 'decline')),
  b_response text check (b_response in ('accept', 'decline')),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'expired', 'cancelled')),
  check (user_a < user_b)
);
-- At most one open offer per pair.
create unique index match_offers_one_pending
  on public.match_offers (user_a, user_b) where status = 'pending';
create index match_offers_b_idx on public.match_offers (user_b);

create table public.blocks (
  blocker uuid not null references public.profiles (id) on delete cascade,
  blocked uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid references public.match_offers (id) on delete set null,
  user_id uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  talked boolean not null default true,
  rating text check (rating in ('veryGood', 'good', 'notReally')),
  want_again boolean,
  created_at timestamptz not null default now()
);

-- Optional phone number for a regular phone call. Never readable by other
-- users directly: revealed only through call_details() to the other side of an
-- offer that BOTH accepted, and only if the owner chose to share it.
create table public.phone_numbers (
  user_id uuid primary key references public.profiles (id) on delete cascade default auth.uid(),
  phone text not null check (phone ~ '^\+?[0-9]{6,15}$'),
  updated_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  reported uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (reason in ('inappropriate', 'harassment', 'spam', 'underage', 'other')),
  created_at timestamptz not null default now()
);

-- --------------------------------------------------------------- helpers

create or replace function public.are_connected(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from connections
    where user_a = least(x, y) and user_b = greatest(x, y)
  );
$$;

create or replace function public.is_blocked_between(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from blocks
    where (blocker = x and blocked = y) or (blocker = y and blocked = x)
  );
$$;

-- ------------------------------------------------------------------- RLS

alter table public.profiles enable row level security;
alter table public.invitations enable row level security;
alter table public.connections enable row level security;
alter table public.availability enable row level security;
alter table public.match_offers enable row level security;
alter table public.blocks enable row level security;
alter table public.feedback enable row level security;
alter table public.reports enable row level security;
alter table public.phone_numbers enable row level security;

-- Profiles: me, and people I'm connected to (unless blocked either way).
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or (public.are_connected(auth.uid(), id)
        and not public.is_blocked_between(auth.uid(), id))
  );
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Invitations: only the inviter sees their own. Created/accepted via functions.
create policy invitations_select on public.invitations for select to authenticated
  using (inviter_id = auth.uid());

-- Connections: only my own pairs. Created via accept_invitation(); I may unmatch.
create policy connections_select on public.connections for select to authenticated
  using (auth.uid() in (user_a, user_b));
create policy connections_delete on public.connections for delete to authenticated
  using (auth.uid() in (user_a, user_b));

-- Availability: mine, and my connections' — only while it hasn't expired.
-- Writes go through set_availability() / clear_availability().
create policy availability_select on public.availability for select to authenticated
  using (
    user_id = auth.uid()
    or (expires_at > now()
        and public.are_connected(auth.uid(), user_id)
        and not public.is_blocked_between(auth.uid(), user_id))
  );
create policy availability_delete on public.availability for delete to authenticated
  using (user_id = auth.uid());

-- Offers: only participants. Answered via respond_offer().
create policy offers_select on public.match_offers for select to authenticated
  using (auth.uid() in (user_a, user_b));

-- Blocks: I see and manage my own blocks only.
create policy blocks_select on public.blocks for select to authenticated
  using (blocker = auth.uid());
create policy blocks_delete on public.blocks for delete to authenticated
  using (blocker = auth.uid());

-- Feedback and reports: write-only for the author (reports aren't readable by clients).
create policy feedback_insert on public.feedback for insert to authenticated
  with check (user_id = auth.uid());
create policy feedback_select on public.feedback for select to authenticated
  using (user_id = auth.uid());
-- Phone number: only my own row.
create policy phones_select on public.phone_numbers for select to authenticated
  using (user_id = auth.uid());
create policy phones_insert on public.phone_numbers for insert to authenticated
  with check (user_id = auth.uid());
create policy phones_update on public.phone_numbers for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy phones_delete on public.phone_numbers for delete to authenticated
  using (user_id = auth.uid());
create policy reports_insert on public.reports for insert to authenticated
  with check (reporter = auth.uid() and reported <> auth.uid());

-- -------------------------------------------------------------- functions

-- Create (or fetch) my profile.
create or replace function public.ensure_profile(p_name text, p_gender text default 'other')
returns public.profiles language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  result profiles;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  insert into profiles (id, display_name, gender)
  values (me, btrim(p_name), coalesce(p_gender, 'other'))
  on conflict (id) do update
    set display_name = excluded.display_name,
        gender = excluded.gender,
        last_seen_at = now()
  returning * into result;
  return result;
end;
$$;

-- A new random, unguessable, one-time invitation (128 bits, URL-safe).
create or replace function public.create_invitation()
returns table (token text, expires_at timestamptz)
language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid();
  t text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from profiles where id = me) then
    raise exception 'no_profile';
  end if;
  if (select count(*) from invitations i
      where i.inviter_id = me and i.accepted_by is null and i.expires_at > now()) >= 20 then
    raise exception 'too_many_open_invitations';
  end if;
  t := translate(encode(extensions.gen_random_bytes(16), 'base64'), '+/=', '-_');
  return query
    insert into invitations (token, inviter_id) values (t, me)
    returning invitations.token, invitations.expires_at;
end;
$$;

-- What the invitee sees before accepting: only the inviter's first name.
create or replace function public.get_invitation(p_token text)
returns table (status text, inviter_name text, inviter_gender text)
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  inv invitations;
  p profiles;
begin
  select * into inv from invitations where token = p_token;
  if not found then
    return query select 'not_found'::text, null::text, null::text; return;
  end if;
  select * into p from profiles where id = inv.inviter_id;
  if me is not null and inv.inviter_id = me then
    return query select 'own'::text, p.display_name, p.gender; return;
  end if;
  if me is not null and are_connected(me, inv.inviter_id) then
    return query select 'already_connected'::text, p.display_name, p.gender; return;
  end if;
  if inv.accepted_by is not null then
    return query select 'used'::text, null::text, null::text; return;
  end if;
  if inv.expires_at <= now() then
    return query select 'expired'::text, null::text, null::text; return;
  end if;
  return query select 'valid'::text, p.display_name, p.gender;
end;
$$;

-- Accept: creates the connection. Safe to call twice.
create or replace function public.accept_invitation(p_token text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  inv invitations;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from profiles where id = me) then
    raise exception 'no_profile';
  end if;
  select * into inv from invitations where token = p_token for update;
  if not found then return 'not_found'; end if;
  if inv.inviter_id = me then return 'own'; end if;
  if are_connected(me, inv.inviter_id) then return 'already_connected'; end if;
  if inv.accepted_by is not null then return 'used'; end if;
  if inv.expires_at <= now() then return 'expired'; end if;
  if is_blocked_between(me, inv.inviter_id) then return 'not_found'; end if;

  insert into connections (user_a, user_b, via_invitation)
  values (least(me, inv.inviter_id), greatest(me, inv.inviter_id), inv.id)
  on conflict do nothing;
  update invitations set accepted_by = me, accepted_at = now() where id = inv.id;
  -- If both happen to be available right now, offer a call.
  perform create_offers_for(me);
  return 'accepted';
end;
$$;

-- Offer a call to every connection that is available right now
-- (no blocks, no open offer, not declined in the last 15 minutes).
create or replace function public.create_offers_for(p_user uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  mine availability;
  other record;
  created integer := 0;
begin
  select * into mine from availability where user_id = p_user and expires_at > now();
  if not found then return 0; end if;
  for other in
    select a.user_id, a.expires_at
    from availability a
    join connections c
      on (c.user_a = p_user and c.user_b = a.user_id)
      or (c.user_b = p_user and c.user_a = a.user_id)
    where a.expires_at > now()
      and not is_blocked_between(p_user, a.user_id)
  loop
    if exists (
      select 1 from match_offers o
      where o.user_a = least(p_user, other.user_id)
        and o.user_b = greatest(p_user, other.user_id)
        and (o.status = 'pending'
             or (o.status = 'declined' and o.updated_at > now() - interval '15 minutes'))
    ) then
      continue;
    end if;
    insert into match_offers (user_a, user_b, expires_at)
    values (least(p_user, other.user_id), greatest(p_user, other.user_id),
            least(mine.expires_at, other.expires_at))
    on conflict do nothing;
    created := created + 1;
  end loop;
  return created;
end;
$$;

-- "I'm free now" for 1–180 minutes.
create or replace function public.set_availability(p_mode text, p_minutes integer)
returns public.availability language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  result availability;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_minutes is null or p_minutes < 1 or p_minutes > 180 then
    raise exception 'invalid_minutes';
  end if;
  insert into availability (user_id, mode, started_at, expires_at)
  values (me, p_mode, now(), now() + make_interval(mins => p_minutes))
  on conflict (user_id) do update
    set mode = excluded.mode,
        started_at = excluded.started_at,
        expires_at = excluded.expires_at
  returning * into result;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return result;
end;
$$;

create or replace function public.clear_availability()
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from availability where user_id = me;
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and me in (user_a, user_b);
end;
$$;

-- Answer an offer. Only when BOTH accept does it become 'accepted'.
-- The other side is never told who declined — just that it didn't work out.
create or replace function public.respond_offer(p_offer uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  answer text := case when p_accept then 'accept' else 'decline' end;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then return 'not_found'; end if;
  if o.status <> 'pending' then return o.status; end if;
  if o.expires_at <= now()
     or not exists (select 1 from availability where user_id = o.user_a and expires_at > now())
     or not exists (select 1 from availability where user_id = o.user_b and expires_at > now()) then
    update match_offers set status = 'expired', updated_at = now() where id = o.id;
    return 'expired';
  end if;

  if me = o.user_a then
    o.a_response := answer;
  else
    o.b_response := answer;
  end if;

  if answer = 'decline' then
    o.status := 'declined';
  elsif o.a_response = 'accept' and o.b_response = 'accept' then
    o.status := 'accepted';
  end if;

  update match_offers
    set a_response = o.a_response, b_response = o.b_response,
        status = o.status, updated_at = now()
  where id = o.id;
  return o.status;
end;
$$;

-- Block: removes the connection and any open offer. Never revealed to them.
create or replace function public.block_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_user = me then return; end if;
  insert into blocks (blocker, blocked) values (me, p_user) on conflict do nothing;
  delete from connections where user_a = least(me, p_user) and user_b = greatest(me, p_user);
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and user_a = least(me, p_user) and user_b = greatest(me, p_user);
end;
$$;

-- After BOTH accepted: the other side's number (if they chose to share it)
-- and whether I share mine. Only for a recently accepted offer of mine.
create or replace function public.call_details(p_offer uuid)
returns table (other_phone text, i_share boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  other uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into o from match_offers where id = p_offer;
  if not found or me not in (o.user_a, o.user_b) or o.status <> 'accepted'
     or o.updated_at < now() - interval '30 minutes' then
    return query select null::text, false; return;
  end if;
  other := case when me = o.user_a then o.user_b else o.user_a end;
  if is_blocked_between(me, other) then
    return query select null::text, false; return;
  end if;
  return query select
    (select phone from phone_numbers where user_id = other),
    exists (select 1 from phone_numbers where user_id = me);
end;
$$;

-- Housekeeping: drop expired availability and close stale offers.
create or replace function public.expire_stale()
returns void language sql security definer set search_path = public as $$
  delete from availability where expires_at <= now();
  update match_offers set status = 'expired', updated_at = now()
  where status = 'pending' and expires_at <= now();
$$;

-- Clients may only call the public API functions.
revoke all on function public.create_offers_for(uuid) from public, anon, authenticated;
revoke all on function public.expire_stale() from public, anon, authenticated;
revoke all on function public.are_connected(uuid, uuid) from public, anon;
revoke all on function public.is_blocked_between(uuid, uuid) from public, anon;
grant execute on function public.are_connected(uuid, uuid) to authenticated;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
revoke all on function public.ensure_profile(text, text) from public, anon;
revoke all on function public.create_invitation() from public, anon;
revoke all on function public.accept_invitation(text) from public, anon;
revoke all on function public.set_availability(text, integer) from public, anon;
revoke all on function public.clear_availability() from public, anon;
revoke all on function public.respond_offer(uuid, boolean) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.call_details(uuid) from public, anon;
grant execute on function public.call_details(uuid) to authenticated;
grant execute on function public.ensure_profile(text, text) to authenticated;
grant execute on function public.create_invitation() to authenticated;
grant execute on function public.get_invitation(text) to authenticated, anon;
grant execute on function public.accept_invitation(text) to authenticated;
grant execute on function public.set_availability(text, integer) to authenticated;
grant execute on function public.clear_availability() to authenticated;
grant execute on function public.respond_offer(uuid, boolean) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;

-- Table privileges (explicit, in case the project doesn't grant them by
-- default). RLS above still decides which ROWS each user may touch.
revoke all on all tables in schema public from anon;
grant select on public.profiles, public.invitations, public.connections,
  public.availability, public.match_offers, public.blocks, public.feedback,
  public.phone_numbers to authenticated;
grant insert, update on public.profiles to authenticated;
grant delete on public.connections, public.availability, public.blocks to authenticated;
grant insert on public.feedback, public.reports to authenticated;
grant insert, update, delete on public.phone_numbers to authenticated;

-- Every minute, clean up (also keeps the "nobody stays free forever" promise
-- when apps are closed). Read paths already ignore expired rows, so if the
-- scheduler isn't available nothing breaks.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('drivetalk-expire-stale', '* * * * *', 'select public.expire_stale()');
exception when others then
  raise notice 'pg_cron not available: %', sqlerrm;
end;
$$;

-- -------------------------------------------------------------- realtime
-- Clients listen for changes and re-read through RLS-protected queries.
alter publication supabase_realtime add table
  public.availability, public.match_offers, public.connections, public.profiles;
