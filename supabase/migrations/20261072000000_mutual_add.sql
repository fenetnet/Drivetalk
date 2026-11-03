-- DriveBond — growth (1.2.1, owner 2026-11-03).
--
-- 1. Mutual add (owner: option ב). Adding someone from my contacts asks
--    them; we're connected once they add me back. Having each other's
--    number no longer connects by itself (a typed number is no proof, D-164).
--    Adding someone who is waiting for me = adding back.
-- 2. Notifications: "X added you — add back?" to the one who decides, and
--    "X added you back" to the one who asked (at most once a day per pair,
--    nothing during quiet hours).
-- 3. Weekly summary: Friday morning, only to who talked with more than 3
--    different people that week (owner; the app's "your week" card counts
--    the same on the phone).
-- 4. my_status also says whom I added who hasn't added me back yet
--    ("asked"), so my list can say "waiting for them".
-- Older apps: same functions and answers. Their "keep?" card approves, and
-- their contacts list now offers the one waiting for them (adding = back).

-- ------------------------------------------------------------ 1. mutual add

create or replace function public.add_contacts(p_users uuid[])
returns table (display_name text)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  other record;
  added boolean := false;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  for other in
    select distinct on (pn.user_id) pn.user_id, pr.display_name,
           exists (select 1 from connections c
                   where c.user_a = least(me, pn.user_id)
                     and c.user_b = greatest(me, pn.user_id)
                     and c.pending_for = me) as waiting_for_me
    from phone_numbers pn
    join profiles pr on pr.id = pn.user_id
    where pn.user_id = any (p_users)
      and pn.user_id <> me
      and pn.phone_hash in (select hash from contact_hashes where owner = me)
      and not kept_apart(me, pn.user_id)
  loop
    if other.waiting_for_me then
      -- They added me first: adding them back connects us.
      update connections set pending_for = null
      where user_a = least(me, other.user_id) and user_b = greatest(me, other.user_id)
        and pending_for = me;
      added := true;
    elsif not are_connected(me, other.user_id) then
      -- They decide (they get "X added you — add back?").
      insert into connections (user_a, user_b, pending_for)
      values (least(me, other.user_id), greatest(me, other.user_id), other.user_id)
      on conflict do nothing;
    else
      continue;
    end if;
    display_name := other.display_name;
    return next;
  end loop;
  if added then perform create_offers_for(me); end if;
end;
$$;
revoke all on function public.add_contacts(uuid[]) from public, anon;
grant execute on function public.add_contacts(uuid[]) to authenticated;

-- Same search as 70, without "I have their number = approved"; someone
-- waiting for me is listed as not yet a friend (adding = adding back).
create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  n integer := coalesce(array_length(p_hashes, 1), 0);
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform pg_advisory_xact_lock(hashtext('find_friends'), hashtext(me::text));
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;
  if n > 5000 then raise exception 'too_many_contacts'; end if;
  if coalesce((select sum(c.n) from contact_search_counts c
               where c.user_id = me and c.at > now() - interval '1 day'), 0) + n > 20000 then
    raise exception 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  insert into contact_search_counts (user_id, n) values (me, n);
  delete from contact_hashes where owner = me;
  if n = 0 then return; end if;
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  return query
    select x.user_id, x.display_name, x.phone_hash, x.is_friend
    from (
      select distinct on (pn.phone_hash)
             pn.user_id, pr.display_name, pn.phone_hash,
             (are_connected(me, pn.user_id)
              and not exists (select 1 from connections c
                              where c.user_a = least(me, pn.user_id)
                                and c.user_b = greatest(me, pn.user_id)
                                and c.pending_for = me)) as is_friend
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

-- ------------------------------------------------------------ 2. notifications

create or replace function public.friend_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  asker uuid;
  decider uuid;
  day text := to_char(now() at time zone 'Asia/Jerusalem', 'YYYYMMDD');
begin
  if tg_op = 'INSERT' and new.pending_for is not null then
    decider := new.pending_for;
    asker := case when new.user_a = decider then new.user_b else new.user_a end;
    if in_quiet_hours(decider) then return null; end if;
    perform push_queue(decider, 'added',
      (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
       from profiles p where p.id = asker),
      'added:' || new.user_a || ':' || new.user_b || ':' || day);
  elsif tg_op = 'UPDATE' and old.pending_for is not null and new.pending_for is null then
    decider := old.pending_for;
    asker := case when new.user_a = decider then new.user_b else new.user_a end;
    if in_quiet_hours(asker) then return null; end if;
    perform push_queue(asker, 'accepted',
      (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
       from profiles p where p.id = decider),
      'accepted:' || new.user_a || ':' || new.user_b || ':' || day);
  end if;
  return null;
end;
$$;
revoke all on function public.friend_push() from public, anon, authenticated;
drop trigger if exists friend_push on public.connections;
create trigger friend_push after insert or update of pending_for on public.connections
  for each row execute function public.friend_push();

-- ------------------------------------------------------------ 3. weekly

-- Talks in the last 7 days: how many, and with how many different people.
create or replace function public.week_of(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'talks', count(*),
    'people', count(distinct case when o.user_a = p_user then o.user_b else o.user_a end))
  from match_offers o
  where p_user in (o.user_a, o.user_b)
    and o.talked
    and o.created_at >= now() - interval '7 days';
$$;
revoke all on function public.week_of(uuid) from public, anon, authenticated;

-- Friday morning: only who talked with more than 3 people this week.
create or replace function public.weekly_summary_tick()
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
  day text := to_char(now() at time zone 'Asia/Jerusalem', 'YYYYMMDD');
begin
  for r in
    select u.id, week_of(u.id) as w
    from (select distinct x.u as id from match_offers o
          cross join lateral (values (o.user_a), (o.user_b)) x(u)
          where o.talked and o.created_at >= now() - interval '7 days') u
  loop
    continue when (r.w ->> 'people')::int <= 3;
    perform push_queue(r.id, 'weekly', r.w, 'weekly:' || r.id || ':' || day);
  end loop;
end;
$$;
revoke all on function public.weekly_summary_tick() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('drivetalk-weekly')
    where exists (select 1 from cron.job where jobname = 'drivetalk-weekly');
    -- Friday 05:37 UTC = 07:37 / 08:37 in Israel.
    perform cron.schedule('drivetalk-weekly', '37 5 * * 5', 'select public.weekly_summary_tick()');
  end if;
end;
$$;

-- ------------------------------------------------------------ 4. my_status

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
    -- friends who added me from their contacts and wait for me to add back
    'pending', coalesce((
      select jsonb_agg(case when c.user_a = me then c.user_b else c.user_a end)
      from connections c
      where c.pending_for = me), '[]'::jsonb),
    -- people I added who haven't added me back yet (1.2.1)
    'asked', coalesce((
      select jsonb_agg(c.pending_for)
      from connections c
      where me in (c.user_a, c.user_b) and c.pending_for is not null
        and c.pending_for <> me), '[]'::jsonb));
end;
$function$;
revoke all on function public.my_status() from public, anon;
grant execute on function public.my_status() to authenticated;

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 72 $$;

insert into public.drivetalk_migrations (name)
values ('20261072000000_mutual_add') on conflict do nothing;

notify pgrst, 'reload schema';
