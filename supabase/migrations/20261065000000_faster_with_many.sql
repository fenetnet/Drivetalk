-- DriveBond — faster with many users (owner, before going public).
--
-- Some requests checked EVERY user in the database to find my friends
-- (quick connect status: 3.6 s with 4,000 test users; activity, my
-- status, friends' profiles: about 0.5 s each). Now they start from my
-- friends list. Same answers, nothing else changes.

-- My friends' ids (every connection, as "are connected" counts them).
create or replace function private.friend_ids(p_me uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select user_b from connections where user_a = p_me
  union all
  select user_a from connections where user_b = p_me;
$$;
revoke all on function private.friend_ids(uuid) from public, anon;
-- Like the other policy helpers in "private" (not reachable from the API).
grant execute on function private.friend_ids(uuid) to authenticated;

-- Functions call the public copy (D-110).
create or replace function public.friend_ids(p_me uuid)
returns setof uuid language sql stable security definer set search_path = public as $$
  select private.friend_ids(p_me);
$$;
revoke all on function public.friend_ids(uuid) from public, anon, authenticated;

-- Profiles I can read: me, and my friends (not blocked, not an old
-- account of someone who has a newer one) — checked only for friends.
alter policy profiles_select on public.profiles
  using (
    id = (select auth.uid())
    or (id in (select private.friend_ids((select auth.uid())))
        and not private.is_blocked_between((select auth.uid()), id)
        and not private.replaced_for((select auth.uid()), id)));

create or replace function public.quick_status()
returns table (user_id uuid, mine boolean, theirs boolean)
language sql stable security definer set search_path = public as $$
  select f.id, is_quick(auth.uid(), f.id), is_quick(f.id, auth.uid())
  from (select friend_ids(auth.uid()) as id) f
  where f.id <> auth.uid()
    and (is_quick(auth.uid(), f.id) or is_quick(f.id, auth.uid()))
    and not is_blocked_between(auth.uid(), f.id);
$$;
revoke all on function public.quick_status() from public, anon;
grant execute on function public.quick_status() to authenticated;

create or replace function public.friends_activity()
returns table (user_id uuid, days integer)
language sql stable security definer set search_path = public as $$
  select p.id, floor(extract(epoch from now() - p.last_seen_at) / 86400)::integer
  from profiles p
  where p.id in (select friend_ids(auth.uid()))
    and p.id <> auth.uid()
    and not is_blocked_between(auth.uid(), p.id);
$$;
revoke all on function public.friends_activity() from public, anon;
grant execute on function public.friends_activity() to authenticated;

create or replace function public.my_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    'quiet_days', p.quiet_days,
    'quiet_ranges', quiet_list(p),
    'auto_missed', p.auto_missed,
    'trip_notify', p.trip_notify,
    -- free friends I can't see by name (theirs or my "without my name")
    'hidden_free', (
      select count(*) from availability a
      where a.user_id in (select friend_ids(me))
        and sees_free_apart_from_name(me, a)
        and (is_anonymous(a.user_id) or p.anonymous)
        and not coalesce(a.call_until > now() or a.phone_until > now(), false)),
    -- friends who added me from their contacts and wait for me to keep them
    'pending', coalesce((
      select jsonb_agg(case when c.user_a = me then c.user_b else c.user_a end)
      from connections c
      where c.pending_for = me), '[]'::jsonb));
end;
$function$;
revoke all on function public.my_status() from public, anon;
grant execute on function public.my_status() to authenticated;

-- Last: the version says 65 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 65 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261065000000_faster_with_many') on conflict do nothing;

notify pgrst, 'reload schema';
