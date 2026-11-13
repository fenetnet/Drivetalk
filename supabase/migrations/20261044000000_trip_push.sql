-- DriveBond — push notifications, and "X is on the way" for quick-connect
-- friends (D-119).
--
-- The owner: someone set up for quick connect gets a notification when I
-- start a trip, so they can call me. On by default, a switch in Settings.
-- - Only friends with quick connect turned on BOTH ways.
-- - Only friends who may see that I'm free (my groups, modes, hide/anonymous).
-- - At most once a day per friend, never in their quiet hours, not when
--   they are free themselves (quick connect already handles that), not when
--   they asked not to be offered me (rating 0) or chose a pause.
-- - After the first quiet minutes of an automatic trip.
-- Push tokens (Firebase) are kept per phone; only the server reads them.

create table if not exists public.push_tokens (
  token text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from public, anon, authenticated;

create table if not exists public.trip_pushes (
  owner uuid not null references public.profiles(id) on delete cascade,
  member uuid not null references public.profiles(id) on delete cascade,
  sent_at timestamptz not null default now(),
  primary key (owner, member)
);
alter table public.trip_pushes enable row level security;
revoke all on public.trip_pushes from public, anon, authenticated;

alter table public.profiles add column if not exists trip_notify boolean not null default true;

-- This phone's push token (a new one replaces the old; at most 5 per person).
create or replace function public.save_push_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then return; end if;
  insert into push_tokens (token, user_id) values (p_token, me)
  on conflict (token) do update set user_id = excluded.user_id, updated_at = now();
  delete from push_tokens t
  where t.user_id = me
    and t.token not in (select token from push_tokens where user_id = me
                        order by updated_at desc limit 5);
end;
$$;
revoke all on function public.save_push_token(text) from public, anon;
grant execute on function public.save_push_token(text) to authenticated;

-- Signing out on this phone.
create or replace function public.forget_push_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = p_token and user_id = auth.uid();
$$;
revoke all on function public.forget_push_token(text) from public, anon;
grant execute on function public.forget_push_token(text) to authenticated;

-- The Settings switch.
create or replace function public.set_trip_notify(p_on boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update profiles set trip_notify = coalesce(p_on, true) where id = auth.uid();
end;
$$;
revoke all on function public.set_trip_notify(boolean) from public, anon;
grant execute on function public.set_trip_notify(boolean) to authenticated;

-- my_status: + the switch.
create or replace function public.my_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  p profiles;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  select * into p from profiles where id = me;
  return jsonb_build_object(
    'anonymous', p.anonymous,
    'hide_in_call', p.hide_in_call,
    'quiet_from', p.quiet_from,
    'quiet_to', p.quiet_to,
    'auto_missed', p.auto_missed,
    'trip_notify', p.trip_notify,
    -- free friends I can't see by name (theirs or my "without my name")
    'hidden_free', (
      select count(*) from availability a
      where a.user_id <> me
        and sees_free_apart_from_name(me, a)
        and (is_anonymous(a.user_id) or p.anonymous)
        and not coalesce(a.call_until > now() or a.phone_until > now(), false)),
    -- friends who added me from their contacts and wait for me to keep them
    'pending', coalesce((
      select jsonb_agg(case when c.user_a = me then c.user_b else c.user_a end)
      from connections c
      where c.pending_for = me), '[]'::jsonb));
end;
$$;
revoke all on function public.my_status() from public, anon;
grant execute on function public.my_status() to authenticated;

-- Who gets "X is on the way" now (and they are marked as told). Called by
-- the push server function only (service role).
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
    where f.id <> p_user
      and is_quick(p_user, f.id) and is_quick(f.id, p_user)
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

-- The background service on the phone identifies itself by its device token.
create or replace function public.push_user_for_device(p_token text)
returns uuid language sql stable security definer set search_path = public as $$
  select device_user(p_token);
$$;
revoke all on function public.push_user_for_device(text) from public, anon, authenticated;
grant execute on function public.push_user_for_device(text) to service_role;

-- A token Firebase says is gone.
create or replace function public.drop_push_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = p_token;
$$;
revoke all on function public.drop_push_token(text) from public, anon, authenticated;
grant execute on function public.drop_push_token(text) to service_role;

-- Last: the version says 44 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 44 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261044000000_trip_push') on conflict do nothing;
