-- DriveBond — a friend who reinstalled doesn't vanish (D-102).
--
-- D-099/D-101 hid a friend's old account (same number, replaced by a newer
-- one). But when I'm NOT yet connected to the new account, the friend simply
-- vanished from my list. Now:
-- - the old account is hidden from me only if I'm already connected to the
--   new one (so it's a duplicate for me, not a disappearance);
-- - the contacts search offers the person's CURRENT account, so the usual
--   "X from your contacts joined — add?" card brings them back in one tap
--   (nobody is connected automatically, D-074).
-- The owner's numbers count PEOPLE (one per phone number), not accounts.

create or replace function public.schema_version()
returns integer language sql immutable as $$ select 30 $$;
grant execute on function public.schema_version() to anon, authenticated;

-- Is p_user an old account that p_viewer already has (connected) in its
-- newer form? (Internal; the profiles policy uses it.)
create or replace function public.replaced_for(p_viewer uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from phone_numbers mine
    join profiles me on me.id = mine.user_id
    join phone_numbers other
      on other.phone_hash = mine.phone_hash and other.user_id <> mine.user_id
    join profiles newer on newer.id = other.user_id
    where mine.user_id = p_user
      and mine.phone_hash is not null
      and are_connected(p_viewer, other.user_id)
      and (
        newer.created_at > me.last_seen_at
        or (me.last_seen_at < now() - interval '1 day'
            and newer.last_seen_at > me.last_seen_at)));
$$;
revoke all on function public.replaced_for(uuid, uuid) from public, anon;
grant execute on function public.replaced_for(uuid, uuid) to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or (public.are_connected(auth.uid(), id)
        and not public.is_blocked_between(auth.uid(), id)
        and not public.replaced_for(auth.uid(), id))
  );

-- Contacts search: per number, the person's current account (not one they
-- replaced by reinstalling), a friend first, else the most recently active.
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
      select distinct on (pn.phone_hash)
             pn.user_id, pr.display_name, pn.phone_hash,
             are_connected(me, pn.user_id) as is_friend
      from phone_numbers pn
      join profiles pr on pr.id = pn.user_id
      where pn.user_id <> me
        and pn.phone_hash in (select c.hash from contact_hashes c where c.owner = me)
        and not is_blocked_between(me, pn.user_id)
      order by pn.phone_hash,
               -- the account they use now, not one they reinstalled over
               replaced_account(pn.user_id) asc,
               are_connected(me, pn.user_id) desc,
               pr.last_seen_at desc
    ) x
    where x.is_friend or not was_removed(me, x.user_id)
    order by x.display_name;
end;
$$;

-- The owner's numbers: people (one per phone number), not accounts.
create or replace function public.app_stats(p_days integer default 7)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since timestamptz := now() - make_interval(days => least(greatest(coalesce(p_days, 7), 1), 365));
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not is_owner() then raise exception 'not_owner'; end if;
  return jsonb_build_object(
    'users', (select count(distinct coalesce(n.phone_hash, p.id::text))
              from profiles p left join phone_numbers n on n.user_id = p.id),
    'new_users', (select count(distinct coalesce(n.phone_hash, p.id::text))
                  from profiles p left join phone_numbers n on n.user_id = p.id
                  where p.created_at >= since
                    and not exists (select 1 from phone_numbers o join profiles op on op.id = o.user_id
                                    where o.phone_hash = n.phone_hash and o.user_id <> p.id
                                      and op.created_at < since)),
    'active_users', (select count(distinct coalesce(n.phone_hash, p.id::text))
                     from profiles p left join phone_numbers n on n.user_id = p.id
                     where p.last_seen_at >= since),
    'friendships', (select count(*) from connections c
                    where not replaced_account(c.user_a) and not replaced_account(c.user_b)),
    'free_times', (select count(*) from app_events where name = 'availability_started' and created_at >= since),
    'offers', (select count(*) from match_offers where created_at >= since and not quick),
    'quick', (select count(*) from match_offers where created_at >= since and quick),
    'both_yes', (select count(*) from match_offers where created_at >= since and status = 'accepted'),
    'talked', (select count(*) from match_offers where created_at >= since and talked),
    'declined', (select count(*) from match_offers where created_at >= since and status = 'declined'),
    'later', (select count(*) from match_offers where created_at >= since and later_from is not null),
    'no_answer', (select count(*) from match_offers where created_at >= since and status = 'expired'),
    'reports', (select count(*) from reports where created_at >= since),
    'feedback', (select count(*) from feedback_notes where created_at >= since),
    'dial_ms', (select percentile_cont(0.5) within group (order by ms)
                from app_events where name = 'dial_started' and ms is not null and created_at >= since)
  );
end;
$$;
revoke all on function public.app_stats(integer) from public, anon;
grant execute on function public.app_stats(integer) to authenticated;

insert into public.drivetalk_migrations (name)
values ('20261030000000_reinstall_keeps_friends') on conflict do nothing;
