-- DriveTalk — automatic availability while driving (Phase 4).
--
-- The phone detects "probably in a vehicle" on its own (Android Activity
-- Recognition — no GPS) and must update availability even when the app is
-- closed. For that, each phone gets its own random device token (only its
-- SHA-256 hash is stored here). The token can do exactly four things for its
-- owner: start/stop automatic DRIVING availability, list open offers (names
-- only) and say "not now". Nothing else. Revoked when the feature is turned
-- off. Location, route and speed are never sent.

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  last_used_at timestamptz not null default now()
);
alter table public.device_tokens enable row level security;
-- No policies: only the functions below touch this table.

-- Who set the availability: the person, or the automatic driving detection.
alter table public.availability
  add column if not exists source text not null default 'manual'
  check (source in ('manual', 'auto'));

-- Manual "I'm free" always marks the row as manual (and so is never stopped
-- by the automatic "trip ended").
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
  insert into availability (user_id, mode, started_at, expires_at, source)
  values (me, p_mode, now(), now() + make_interval(mins => p_minutes), 'manual')
  on conflict (user_id) do update
    set mode = excluded.mode,
        started_at = excluded.started_at,
        expires_at = excluded.expires_at,
        source = 'manual'
  returning * into result;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return result;
end;
$$;

-- A new device token for this phone (replaces this user's older ones).
create or replace function public.create_device_token()
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid();
  t text;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from profiles where id = me) then
    raise exception 'no_profile';
  end if;
  delete from device_tokens where user_id = me;
  t := translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/=', '-_');
  insert into device_tokens (user_id, token_hash)
  values (me, encode(extensions.digest(t, 'sha256'), 'hex'));
  return t;
end;
$$;

create or replace function public.revoke_device_tokens()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from device_tokens where user_id = auth.uid();
end;
$$;

-- Internal: token → user (null if unknown).
create or replace function public.device_user(p_token text)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare
  u uuid;
begin
  if p_token is null or length(p_token) < 30 then return null; end if;
  update device_tokens set last_used_at = now()
  where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
  returning user_id into u;
  return u;
end;
$$;

-- Trip started: driving availability (unless I'm already free manually).
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
    set mode = 'driving', started_at = now(),
        expires_at = now() + make_interval(mins => mins), source = 'auto';
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return 'available';
end;
$$;

-- Trip ended: stop only availability that the detection itself started.
create or replace function public.auto_stop(p_token text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return 'bad_token'; end if;
  if not exists (select 1 from availability where user_id = me and source = 'auto') then
    return 'nothing';
  end if;
  delete from availability where user_id = me and source = 'auto';
  update match_offers set status = 'cancelled', updated_at = now()
  where status = 'pending' and me in (user_a, user_b);
  return 'stopped';
end;
$$;

-- Open questions for me ("X is free — talk?"): offer id + first name only.
create or replace function public.auto_offers(p_token text)
returns table (offer_id uuid, other_name text)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return; end if;
  return query
    select o.id, p.display_name
    from match_offers o
    join profiles p on p.id = case when o.user_a = me then o.user_b else o.user_a end
    where o.status = 'pending'
      and o.expires_at > now()
      and me in (o.user_a, o.user_b)
      and (case when o.user_a = me then o.a_response else o.b_response end) is null
      and not is_blocked_between(o.user_a, o.user_b)
    order by o.created_at;
end;
$$;

-- "Not now" from the notification (saying YES always opens the app).
create or replace function public.auto_decline(p_token text, p_offer uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  o match_offers;
begin
  if me is null then return 'bad_token'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then return 'not_found'; end if;
  if o.status <> 'pending' then return o.status; end if;
  update match_offers
    set a_response = case when me = o.user_a then 'decline' else a_response end,
        b_response = case when me = o.user_b then 'decline' else b_response end,
        status = 'declined', updated_at = now()
  where id = o.id;
  return 'declined';
end;
$$;

revoke all on function public.device_user(text) from public, anon, authenticated;
revoke all on function public.create_device_token() from public, anon;
revoke all on function public.revoke_device_tokens() from public, anon;
grant execute on function public.create_device_token() to authenticated;
grant execute on function public.revoke_device_tokens() to authenticated;
-- Called by the phone in the background with its device token only.
grant execute on function public.auto_start(text, integer) to anon, authenticated;
grant execute on function public.auto_stop(text) to anon, authenticated;
grant execute on function public.auto_offers(text) to anon, authenticated;
grant execute on function public.auto_decline(text, uuid) to anon, authenticated;
