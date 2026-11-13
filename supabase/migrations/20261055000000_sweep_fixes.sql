-- DriveBond — fixes from the bug sweep (D-134).
--
-- 1. Blocked or removed stays blocked or removed after a reinstall: someone
--    I blocked (or removed) who reinstalled has a new account with the same
--    number. The contacts search / add / "why isn't X here?" now treat every
--    account of that number the same way.
-- 2. "Why isn't X here?" no longer tells me that X blocked ME (it says "not
--    on DriveBond", as if they weren't there). "Blocked" only when I blocked.
-- 3. "In a call" ends with the phone call only for an app call agreed BEFORE
--    that phone call began (an earlier, unrelated phone call that ends later
--    doesn't close a call agreed in the meantime).
-- 4. "X tried to reach you" respects my quiet hours.
-- 5. The widget: a friend's old account (replaced by reinstalling) isn't
--    shown twice, and the 10 shown are the right 10 (sorted before the cut).

-- ------------------------------------------------------------ 1 + 2

-- Every account with one of p_user's numbers (p_user included).
create or replace function public.same_number_accounts(p_user uuid)
returns table (user_id uuid) language sql stable security definer set search_path = public as $$
  select p_user
  union
  select other.user_id
  from phone_numbers mine
  join phone_numbers other on other.phone_hash = mine.phone_hash
  where mine.user_id = p_user and mine.phone_hash is not null;
$$;
revoke all on function public.same_number_accounts(uuid) from public, anon, authenticated;

-- Did any account of mine and any account of this person (by number) block
-- or remove each other?
-- Did any account of mine and any account of this person (by number) block
-- (blocked_any) or remove (kept_apart: either) each other?
create or replace function public.blocked_any(me uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  with m as (select user_id from same_number_accounts(me)),
       k as (select user_id from same_number_accounts(p_user))
  select exists (
    select 1 from blocks b
    where (b.blocker in (select user_id from m) and b.blocked in (select user_id from k))
       or (b.blocker in (select user_id from k) and b.blocked in (select user_id from m)));
$$;
revoke all on function public.blocked_any(uuid, uuid) from public, anon, authenticated;

create or replace function public.kept_apart(me uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  with m as (select user_id from same_number_accounts(me)),
       k as (select user_id from same_number_accounts(p_user))
  select blocked_any(me, p_user) or exists (
    select 1 from removed_pairs r
    where (r.user_a in (select user_id from m) and r.user_b in (select user_id from k))
       or (r.user_a in (select user_id from k) and r.user_b in (select user_id from m)));
$$;
revoke all on function public.kept_apart(uuid, uuid) from public, anon, authenticated;

create or replace function public.add_contacts(p_users uuid[])
returns table (display_name text) language plpgsql security definer set search_path = public as $$
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
            case when exists (
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
revoke all on function public.add_contacts(uuid[]) from public, anon;
grant execute on function public.add_contacts(uuid[]) to authenticated;

create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    raise exception 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  delete from contact_hashes where owner = me;
  if p_hashes is null or array_length(p_hashes, 1) is null then return; end if;
  if array_length(p_hashes, 1) > 5000 then raise exception 'too_many_contacts'; end if;
  insert into contact_hashes (owner, hash)
  select distinct me, h from unnest(p_hashes) as h
  where h ~ '^[0-9a-f]{64}$'
    and exists (select 1 from phone_numbers pn where pn.phone_hash = h and pn.user_id <> me)
  on conflict do nothing;

  update connections c set pending_for = null
  where c.pending_for = me
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
revoke all on function public.find_friends(text[]) from public, anon;
grant execute on function public.find_friends(text[]) to authenticated;

create or replace function public.contact_check(p_hash text)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  other uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_hash is null or p_hash !~ '^[0-9a-f]{64}$' then return 'bad'; end if;
  if (select count(*) from contact_searches cs
      where cs.user_id = me and cs.at > now() - interval '1 day') >= 30 then
    return 'rate_limited';
  end if;
  insert into contact_searches (user_id) values (me);
  if exists (select 1 from phone_numbers where user_id = me and phone_hash = p_hash) then
    return 'me';
  end if;
  select pn.user_id into other
  from phone_numbers pn join profiles pr on pr.id = pn.user_id
  where pn.phone_hash = p_hash
  order by replaced_account(pn.user_id) asc, pr.last_seen_at desc
  limit 1;
  if other is null then return 'not_user'; end if;
  -- Blocked by them: as if they weren't here (never tell who blocked me).
  if exists (select 1 from same_number_accounts(me) m, same_number_accounts(other) k
             join blocks b on b.blocker = k.user_id
             where b.blocked = m.user_id) then
    return 'not_user';
  end if;
  if exists (select 1 from same_number_accounts(me) m, same_number_accounts(other) k
             join blocks b on b.blocked = k.user_id
             where b.blocker = m.user_id) then
    return 'blocked';
  end if;
  if are_connected(me, other) then return 'friend'; end if;
  if kept_apart(me, other) then return 'removed'; end if;
  return 'user';
end;
$$;
revoke all on function public.contact_check(text) from public, anon;
grant execute on function public.contact_check(text) to authenticated;

-- ------------------------------------------------------------ 3

alter table public.availability add column if not exists phone_since timestamptz;

create or replace function public.device_phone_call(p_token text, p_on boolean)
returns text language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  since timestamptz;
begin
  if me is null then return 'bad_token'; end if;
  select case when phone_until is not null then coalesce(phone_since, now()) end
  into since from availability where user_id = me;
  update availability
  set phone_until = case when p_on then now() + interval '3 minutes' else null end,
      phone_since = case
        when not p_on then null
        when phone_until > now() then coalesce(phone_since, now())
        else now() end
  where user_id = me;
  if p_on then
    update match_offers set status = 'cancelled', updated_at = now()
    where status = 'pending' and me in (user_a, user_b);
  elsif since is not null then
    -- The phone call is over: so is my side of an app call agreed before it.
    update match_offers
    set ended_a = ended_a or me = user_a,
        ended_b = ended_b or me = user_b,
        updated_at = now()
    where status = 'accepted' and me in (user_a, user_b)
      and accepted_at is not null and accepted_at > now() - interval '2 hours'
      and accepted_at <= since
      and not (case when me = user_a then ended_a else ended_b end)
      and (not quick or (not_before is not null and not_before < now()));
  end if;
  return 'ok';
end;
$$;
revoke all on function public.device_phone_call(text, boolean) from public;
grant execute on function public.device_phone_call(text, boolean) to anon, authenticated;

-- ------------------------------------------------------------ 4

create or replace function public.missed_push()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  side record;
begin
  if new.status in ('declined', 'expired', 'cancelled')
     and old.status = 'pending' and not new.quick then
    for side in
      select new.user_a as me, new.user_b as other
      where new.a_response is null and new.b_response = 'accept'
      union all
      select new.user_b, new.user_a
      where new.b_response is null and new.a_response = 'accept'
    loop
      continue when in_quiet_hours(side.me);
      perform push_queue(side.me, 'missed',
        (select jsonb_build_object('from', p.id, 'name', p.display_name, 'gender', p.gender)
         from profiles p where p.id = side.other),
        'missed:' || side.me || ':' || (
          select to_char(now() at time zone coalesce(p.time_zone, 'Asia/Jerusalem'), 'YYYYMMDD')
          from profiles p where p.id = side.me));
    end loop;
  end if;
  return null;
end;
$$;
revoke all on function public.missed_push() from public, anon, authenticated;

-- ------------------------------------------------------------ 5

create or replace function public.device_free_friends(p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
begin
  if me is null then return '[]'::jsonb; end if;
  if is_anonymous(me) then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(t.x order by t.busy, t.until desc)
    from (
      select jsonb_build_object(
               'id', a.user_id,
               'name', p.display_name,
               'mode', a.mode,
               'until', a.expires_at,
               'busy', b.busy) as x,
             b.busy, a.expires_at as until
      from availability a
      join profiles p on p.id = a.user_id
      cross join lateral (select coalesce(a.call_until > now() or a.phone_until > now(), false) as busy) b
      where a.user_id <> me
        and sees_free_apart_from_name(me, a)
        and not is_anonymous(a.user_id)
        and not replaced_for(me, a.user_id)
      order by b.busy, a.expires_at desc
      limit 10
    ) t), '[]'::jsonb);
end;
$$;
revoke all on function public.device_free_friends(text) from public;
grant execute on function public.device_free_friends(text) to anon, authenticated;

-- Last: the version says 55 only once everything above is in.
create or replace function public.schema_version()
returns integer language sql immutable as $$ select 55 $$;
grant execute on function public.schema_version() to anon, authenticated;

insert into public.drivetalk_migrations (name)
values ('20261055000000_sweep_fixes') on conflict do nothing;
