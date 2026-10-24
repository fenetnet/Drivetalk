-- DriveBond — fixes from the full review (D-094). Nothing changes for the
-- user; these close privacy leaks and consent holes:
--
--  1. Friends could read the exact time I was last active / became free
--     (profiles.last_seen_at). Now only the columns the app shows are
--     readable, and profiles are no longer sent over Realtime.
--  2. Realtime sent every DELETE to everyone (deletes skip RLS): who removed
--     whom, private circles, when people stopped being free. Now only
--     inserts and updates are sent; the app's regular refresh covers the rest.
--  3. The contacts search had no limit (number scraping): 30 a day.
--  4. Stopping availability (button, trip end, "Stop" in the notification,
--     expiry) now also cancels a quick connect that hasn't started yet.
--  5. An old accepted offer can't be replayed to get someone's number.
--  6. Quick connect: the side that gave up / ended can't be called later; a
--     cancel can't win after the call started; the caller is the side that
--     can actually dial; unseen or cancelled ones don't leave "in a call".
--  7. Blocking a random user id no longer reveals their name.
--  8. Deleting a circle ends availability that was only for that circle; a
--     routine with a deleted circle doesn't start (never "everyone").
--  9. "I'll get back to you" only when it really was my "no".
-- 10. Removing a friend also removes them from my circles (quick connect
--     needs fresh consent).
-- 11. Changing or deleting my number removes its hash from others' contact
--     lists when nobody else has it; account deletion removes owner claims.
-- 12. Feedback can only be about my own offers.
-- 13. Faster: an index for the per-person offer checks.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 26 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- 1. profiles: only what the app shows ------------------------------------
revoke select on public.profiles from authenticated;
grant select (id, display_name, gender, photo_version, hide_status)
  on public.profiles to authenticated;
revoke insert, update on public.profiles from authenticated;
grant update (display_name, gender) on public.profiles to authenticated;

-- 1+2. Realtime: no deletes, no profiles ----------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime set (publish = 'insert, update');
    if exists (select 1 from pg_publication_tables
               where pubname = 'supabase_realtime' and schemaname = 'public'
                 and tablename = 'profiles') then
      alter publication supabase_realtime drop table public.profiles;
    end if;
  end if;
end;
$$;

-- 3. contacts search limit -------------------------------------------------
create table if not exists public.contact_searches (
  user_id uuid not null references public.profiles (id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists contact_searches_user_idx on public.contact_searches (user_id, at);
alter table public.contact_searches enable row level security;
revoke all on public.contact_searches from anon, authenticated;

create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  -- Normal use is a couple of searches a day; this stops number scraping.
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
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
    select x.user_id, x.display_name, x.phone_hash, x.is_friend
    from (
      -- One account per number: a friend first, else the most recently active.
      select distinct on (pn.phone_hash)
             pn.user_id, pr.display_name, pn.phone_hash,
             are_connected(me, pn.user_id) as is_friend
      from phone_numbers pn
      join profiles pr on pr.id = pn.user_id
      where pn.user_id <> me
        and pn.phone_hash in (select c.hash from contact_hashes c where c.owner = me)
        and not is_blocked_between(me, pn.user_id)
      order by pn.phone_hash, are_connected(me, pn.user_id) desc, pr.last_seen_at desc
    ) x
    where x.is_friend or not was_removed(me, x.user_id)
    order by x.display_name;
end;
$$;

-- 4. availability ended → unstarted quick connects end too ---------------
create or replace function public.availability_ended()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- (Not while the whole account is being deleted.)
  if exists (select 1 from profiles where id = old.user_id) then
    update match_offers set status = 'cancelled', updated_at = now()
    where old.user_id in (user_a, user_b)
      and (status = 'pending' or (status = 'accepted' and quick and caller is null));
  end if;
  return old;
end;
$$;
revoke all on function public.availability_ended() from public, anon, authenticated;
drop trigger if exists availability_ended on public.availability;
create trigger availability_ended after delete on public.availability
  for each row execute function public.availability_ended();

-- 5. ----------------------------------------------------------------------
create or replace function public.answer_offer(p_offer uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
  answer text := case when p_accept then 'accept' else 'decline' end;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(727274);
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then
    return jsonb_build_object('status', 'not_found');
  end if;
  if o.status <> 'pending' then
    return jsonb_build_object(
      'status', o.status,
      'i_call', o.caller = me,
      'phone', case when o.status = 'accepted' and o.caller = me and now() >= o.not_before
                     and o.accepted_at > now() - interval '30 minutes'
                     and are_connected(o.user_a, o.user_b)
                    then call_phone_for(o, me) end);
  end if;
  if o.expires_at <= now()
     or not exists (select 1 from availability where user_id = o.user_a and expires_at > now())
     or not exists (select 1 from availability where user_id = o.user_b and expires_at > now()) then
    update match_offers set status = 'expired', updated_at = now() where id = o.id;
    return jsonb_build_object('status', 'expired');
  end if;

  if me = o.user_a then o.a_response := answer; else o.b_response := answer; end if;

  if answer = 'decline' then
    o.status := 'declined';
  elsif o.a_response = 'accept' and o.b_response = 'accept' then
    -- Never two calls at once.
    if in_call(o.user_a, o.id) or in_call(o.user_b, o.id) then
      update match_offers set status = 'expired', updated_at = now() where id = o.id;
      return jsonb_build_object('status', 'expired');
    end if;
    o.status := 'accepted';
    -- I dial (I'm looking at the phone right now) — unless only I shared a
    -- number: then they dial me.
    o.caller := case
      when not exists (select 1 from phone_numbers
                       where user_id = case when me = o.user_a then o.user_b else o.user_a end)
           and exists (select 1 from phone_numbers where user_id = me)
      then case when me = o.user_a then o.user_b else o.user_a end
      else me end;
    o.accepted_at := now();
    o.not_before := now();
  end if;

  update match_offers
    set a_response = o.a_response, b_response = o.b_response, status = o.status,
        caller = o.caller, accepted_at = o.accepted_at, not_before = o.not_before,
        updated_at = now()
  where id = o.id;

  if o.status = 'accepted' then
    -- Anything else that was open for either of them is no longer relevant.
    update match_offers set status = 'cancelled', updated_at = now()
    where status = 'pending' and id <> o.id
      and (o.user_a in (user_a, user_b) or o.user_b in (user_a, user_b));
  end if;

  return jsonb_build_object(
    'status', o.status,
    'i_call', o.status = 'accepted' and o.caller = me,
    'phone', case when o.status = 'accepted' and o.caller = me then call_phone_for(o, me) end);
end;
$$;

-- 6. ----------------------------------------------------------------------
create or replace function public.start_call(p_offer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  o match_offers;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into o from match_offers where id = p_offer for update;
  if not found or me not in (o.user_a, o.user_b) then
    return jsonb_build_object('state', 'gone');
  end if;
  if o.status = 'cancelled' then return jsonb_build_object('state', 'cancelled'); end if;
  -- The other side already gave up / ended: never start it any more.
  if (me = o.user_a and o.ended_b) or (me = o.user_b and o.ended_a) then
    return jsonb_build_object('state', 'gone');
  end if;
  if o.status <> 'accepted' or o.accepted_at < now() - interval '30 minutes'
     or is_blocked_between(o.user_a, o.user_b) then
    return jsonb_build_object('state', 'gone');
  end if;
  if o.not_before is null then
    perform mark_seen(o.id, me);
    select * into o from match_offers where id = p_offer;
  end if;
  if o.not_before is null or now() < o.not_before then
    return jsonb_build_object('state', 'wait', 'wait_ms',
      case when o.not_before is null then 1000
           else greatest(100, ceil(extract(epoch from (o.not_before - now())) * 1000)::int) end);
  end if;
  if o.caller is null then
    -- Like answer_offer: the caller needs the other's number — if only I
    -- shared one, they call me.
    o.caller := case
      when not exists (select 1 from phone_numbers
                       where user_id = case when me = o.user_a then o.user_b else o.user_a end)
           and exists (select 1 from phone_numbers where user_id = me)
      then case when me = o.user_a then o.user_b else o.user_a end
      else me end;
    update match_offers set caller = o.caller, updated_at = now() where id = o.id;
  end if;
  return jsonb_build_object(
    'state', 'ready',
    'i_call', o.caller = me,
    'phone', case when o.caller = me then call_phone_for(o, me) end);
end;
$$;

create or replace function public.cancel_call_for(p_offer uuid, p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  n integer;
begin
  update match_offers set status = 'cancelled', updated_at = now()
  where id = p_offer and p_user in (user_a, user_b) and status = 'accepted'
    and quick and caller is null and (not_before is null or now() < not_before);
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

create or replace function public.in_call(p_user uuid, p_except uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_offers o
    where o.status = 'accepted'
      and o.id is distinct from p_except
      and o.accepted_at > now() - interval '20 minutes'
      and not (o.quick and o.not_before is null and o.accepted_at < now() - interval '2 minutes')
      and ((o.user_a = p_user and not o.ended_a) or (o.user_b = p_user and not o.ended_b))
  );
$$;

create or replace function public.mark_app_call()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted'
     and (tg_op = 'INSERT' or old.status is distinct from 'accepted') then
    update availability
    set call_until = now() + case when new.quick and new.not_before is null
                                  then interval '2 minutes' else interval '20 minutes' end
    where user_id in (new.user_a, new.user_b);
  end if;
  if tg_op = 'UPDATE' then
    -- Quick connect: both phones saw it — now it's a real call.
    if new.status = 'accepted' and new.quick
       and new.not_before is not null and old.not_before is null then
      update availability set call_until = now() + interval '20 minutes'
      where user_id in (new.user_a, new.user_b);
    end if;
    -- Cancelled (or otherwise over): nobody is "in a call" because of it.
    if old.status = 'accepted' and new.status <> 'accepted' then
      update availability set call_until = null where user_id in (new.user_a, new.user_b);
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
drop trigger if exists match_offers_app_call on public.match_offers;
create trigger match_offers_app_call
  after insert or update of status, ended_a, ended_b, not_before on public.match_offers
  for each row execute function public.mark_app_call();

-- 7. ----------------------------------------------------------------------
create or replace function public.block_user(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  had boolean;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_user = me then return; end if;
  -- Only someone I'm (or was) connected with or got an offer with: blocking
  -- a random id must not reveal their name (my_blocks).
  if not (are_connected(me, p_user) or was_removed(me, p_user)
          or exists (select 1 from match_offers
                     where user_a = least(me, p_user) and user_b = greatest(me, p_user))) then
    return;
  end if;
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
revoke all on function public.is_quick(uuid, uuid) from authenticated;

-- 8. circles ----------------------------------------------------------------
create or replace function public.circle_deleted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from availability where circle_id = old.id;
  return old;
end;
$$;
revoke all on function public.circle_deleted() from public, anon, authenticated;
drop trigger if exists circles_end_availability on public.circles;
create trigger circles_end_availability before delete on public.circles
  for each row execute function public.circle_deleted();

create or replace function public.device_start(
  p_token text, p_mode text default 'free', p_minutes integer default 30,
  p_circle uuid default null)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  mins integer := least(greatest(coalesce(p_minutes, 30), 1), 180);
  until timestamptz;
  circle uuid := null;
begin
  if me is null then return null; end if;
  if p_mode not in ('driving', 'walking', 'breakTime', 'free') then
    p_mode := 'free';
  end if;
  if p_circle is not null then
    if not exists (select 1 from circles where id = p_circle and owner = me) then
      return null;
    end if;
    circle := p_circle;
  end if;
  until := now() + make_interval(mins => mins);
  insert into availability (user_id, mode, started_at, expires_at, source, circle_id)
  values (me, p_mode, now(), until, 'manual', circle)
  on conflict (user_id) do update
    set mode = excluded.mode, started_at = now(), expires_at = until,
        source = 'manual', circle_id = circle;
  update profiles set last_seen_at = now() where id = me;
  perform create_offers_for(me);
  return until;
end;
$$;

-- 9. ----------------------------------------------------------------------
create or replace function public.decline_later(p_offer uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  r jsonb;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  r := answer_offer(p_offer, false);
  if r->>'status' = 'declined' then
    update match_offers set later_from = me, updated_at = now()
    where id = p_offer and me in (user_a, user_b)
      and ((me = user_a and a_response = 'decline') or (me = user_b and b_response = 'decline'));
  end if;
  return r;
end;
$$;

-- 10. ---------------------------------------------------------------------
create or replace function public.remember_removed()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    delete from circle_members m using circles c
    where m.circle_id = c.id
      and ((c.owner = old.user_a and m.member = old.user_b)
           or (c.owner = old.user_b and m.member = old.user_a));
    if exists (select 1 from profiles where id = old.user_a)
       and exists (select 1 from profiles where id = old.user_b) then
      insert into removed_pairs (user_a, user_b, removed_by)
      values (old.user_a, old.user_b, auth.uid())
      on conflict (user_a, user_b) do update set removed_by = excluded.removed_by,
                                                 created_at = now();
    end if;
    return old;
  end if;
  delete from removed_pairs where user_a = new.user_a and user_b = new.user_b;
  return new;
end;
$$;

-- 11. my number's hash leaves others' lists with it ------------------------
create or replace function public.phone_hash_cleanup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.phone_hash is not null
     and (tg_op = 'DELETE' or new.phone_hash is distinct from old.phone_hash)
     and not exists (select 1 from phone_numbers
                     where phone_hash = old.phone_hash and user_id <> old.user_id) then
    delete from contact_hashes where hash = old.phone_hash;
  end if;
  return null;
end;
$$;
revoke all on function public.phone_hash_cleanup() from public, anon, authenticated;
drop trigger if exists phone_numbers_hash_cleanup on public.phone_numbers;
create trigger phone_numbers_hash_cleanup after update or delete on public.phone_numbers
  for each row execute function public.phone_hash_cleanup();

delete from public.owner_claims o where not exists (select 1 from public.profiles p where p.id = o.user_id);
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  delete from public.owner_claims where user_id = me;
  delete from public.profiles where id = me;
  delete from auth.users where id = me;
end;
$$;

create or replace function public.claim_owner(p_code text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from owner_claims where user_id = me and at > now() - interval '1 hour') >= 5
     or (select count(*) from owner_claims where at > now() - interval '1 hour') >= 100 then
    return false;
  end if;
  insert into owner_claims (user_id) values (me);
  if not exists (
    select 1 from owner_secret
    where id = 1
      and code_hash = encode(extensions.digest('drivetalk-admin:' || btrim(coalesce(p_code, '')), 'sha256'), 'hex')
  ) then
    return false;
  end if;
  insert into app_owners (user_id) values (me) on conflict do nothing;
  return true;
end;
$$;

-- 12. feedback only about my own offers -------------------------------------
drop policy if exists feedback_insert on public.feedback;
create policy feedback_insert on public.feedback for insert to authenticated
  with check (
    user_id = auth.uid()
    and (offer_id is null
         or exists (select 1 from public.match_offers o
                    where o.id = offer_id and auth.uid() in (o.user_a, o.user_b)))
  );

-- 13. -----------------------------------------------------------------------
create index if not exists match_offers_user_a_idx on public.match_offers (user_a);

insert into public.drivetalk_migrations (name)
values ('20261026000000_review_fixes') on conflict do nothing;
