-- DriveTalk — one person once, names as saved in MY phone, report count (D-077).
--
--   * Reinstalling the app makes a new account with the same number; the
--     old one stays behind. Contacts now show each number once: the account
--     that was active most recently.
--   * find_friends also returns the hash that matched (the hash I sent, so
--     nothing new is revealed) and whether that person is already my friend:
--     the app shows people by the name saved in MY contacts ("Mom"). Names
--     never leave the phone.
--   * The background service gets the other person's id, for the same names.
--   * Owner numbers: how many reports.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 19 $$;
grant execute on function public.schema_version() to anon, authenticated;

drop function if exists public.find_friends(text[]);
create or replace function public.find_friends(p_hashes text[])
returns table (user_id uuid, display_name text, hash text, is_friend boolean)
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
revoke all on function public.find_friends(text[]) from public, anon;
grant execute on function public.find_friends(text[]) to authenticated;

-- Older app versions: same as before (nobody is connected).
create or replace function public.sync_contacts(p_hashes text[])
returns table (display_name text)
language sql security definer set search_path = public as $$
  select null::text from public.find_friends(p_hashes) where false;
$$;
revoke all on function public.sync_contacts(text[]) from public, anon;
grant execute on function public.sync_contacts(text[]) to authenticated;

drop function if exists public.auto_offers(text);
create or replace function public.auto_offers(p_token text)
returns table (offer_id uuid, other_name text, kind text, not_before timestamptz, other_id uuid)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := device_user(p_token);
  q record;
begin
  if me is null then return; end if;
  perform create_offers_for(me);
  for q in
    select o.id from match_offers o
    where me in (o.user_a, o.user_b) and o.quick and o.status = 'accepted'
      and o.not_before is null and o.accepted_at > now() - interval '3 minutes'
  loop
    perform mark_seen(q.id, me);
  end loop;
  return query
    select o.id, p.display_name,
           case when o.quick then 'quick' else 'ask' end,
           o.not_before,
           p.id
    from match_offers o
    join profiles p on p.id = case when o.user_a = me then o.user_b else o.user_a end
    where me in (o.user_a, o.user_b)
      and not is_blocked_between(o.user_a, o.user_b)
      and (
        (o.status = 'pending' and o.expires_at > now()
         and (case when o.user_a = me then o.a_response else o.b_response end) is null)
        or (o.quick and o.status = 'accepted' and o.accepted_at > now() - interval '3 minutes'
            and o.caller is null)
      )
    order by o.created_at;
end;
$$;
grant execute on function public.auto_offers(text) to anon, authenticated;

create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return jsonb_build_object(
    'users', (select count(*) from profiles),
    'new_users', (select count(*) from profiles where created_at >= since),
    'active_users', (select count(*) from profiles where last_seen_at >= since),
    'friendships', (select count(*) from connections),
    'free_times', (select count(*) from app_events where name = 'availability_started' and created_at >= since),
    'offers', (select count(*) from match_offers where created_at >= since and not quick),
    'quick', (select count(*) from match_offers where created_at >= since and quick),
    'both_yes', (select count(*) from match_offers where created_at >= since and status = 'accepted'),
    'talked', (select count(*) from match_offers where created_at >= since and talked),
    'declined', (select count(*) from match_offers where created_at >= since and status = 'declined'),
    'later', (select count(*) from match_offers where created_at >= since and later_from is not null),
    'no_answer', (select count(*) from match_offers where created_at >= since and status = 'expired'),
    'reports', (select count(*) from reports where created_at >= since),
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  );
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261019000000_one_person_local_names') on conflict do nothing;
